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
