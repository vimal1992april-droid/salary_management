import { QueryClientProvider } from '@tanstack/react-query'
import { renderHook, waitFor } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import type { ReactNode } from 'react'
import { describe, expect, it } from 'vitest'
import { ApiError } from './api/client'
import { useSession } from './auth/session'
import { createQueryClient } from './queryClient'
import { hr, signedIn, signedOut } from './test/helpers'
import { server } from './test/server'

describe('createQueryClient', () => {
  it('retries an unreachable server twice, but never retries a real answer from the API', () => {
    const retry = createQueryClient().getDefaultOptions().queries?.retry as (failures: number, error: Error) => boolean
    const unreachable = new ApiError(0, 'Could not reach the server', 'network_error')

    expect(retry(0, unreachable)).toBe(true)
    expect(retry(1, unreachable)).toBe(true)
    expect(retry(2, unreachable)).toBe(false)
    expect(retry(0, new ApiError(500, 'Request failed (500)'))).toBe(false)
    expect(retry(0, new ApiError(404, 'Not found', 'not_found'))).toBe(false)
  })

  it('does not retry at all when told not to, as in tests', () => {
    expect(createQueryClient({ retry: false }).getDefaultOptions().queries?.retry).toBe(false)
  })

  it('re-checks the session when any request comes back 401, so an expired session ends up at sign-in', async () => {
    signedIn()
    const client = createQueryClient({ retry: false })
    const wrapper = ({ children }: { children: ReactNode }) => (
      <QueryClientProvider client={client}>{children}</QueryClientProvider>
    )
    const { result } = renderHook(() => useSession(), { wrapper })
    await waitFor(() => expect(result.current.data).toEqual(hr))

    signedOut() // the session has expired on the server
    await client
      .fetchQuery({
        queryKey: ['employees'],
        queryFn: () => {
          throw new ApiError(401, 'Please sign in to continue', 'unauthenticated')
        },
      })
      .catch(() => undefined)

    await waitFor(() => expect(result.current.data).toBeNull())
  })

  it('does not touch the session for other errors', async () => {
    let sessionChecks = 0
    server.use(http.get('*/api/session', () => (sessionChecks++, HttpResponse.json({ user: hr }))))
    const client = createQueryClient({ retry: false })
    const wrapper = ({ children }: { children: ReactNode }) => (
      <QueryClientProvider client={client}>{children}</QueryClientProvider>
    )
    const { result } = renderHook(() => useSession(), { wrapper })
    await waitFor(() => expect(result.current.data).toEqual(hr))

    await client
      .fetchQuery({
        queryKey: ['employees'],
        queryFn: () => {
          throw new ApiError(500, 'Request failed (500)')
        },
      })
      .catch(() => undefined)

    expect(sessionChecks).toBe(1)
  })
})
