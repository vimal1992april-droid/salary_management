import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '../test/server'
import { ApiError, apiFetch } from './client'

describe('apiFetch', () => {
  it('returns the parsed JSON body of a successful response', async () => {
    server.use(http.get('*/api/ping', () => HttpResponse.json({ pong: true })))

    await expect(apiFetch<{ pong: boolean }>('/api/ping')).resolves.toEqual({ pong: true })
  })

  it('throws an ApiError with the status and server message when the response is not ok', async () => {
    server.use(
      http.get('*/api/ping', () =>
        HttpResponse.json({ error: { code: 'not_found', message: 'Employee not found' } }, { status: 404 }),
      ),
    )

    const failure = apiFetch('/api/ping')

    await expect(failure).rejects.toBeInstanceOf(ApiError)
    await expect(failure).rejects.toMatchObject({ status: 404, code: 'not_found', message: 'Employee not found' })
  })

  it('falls back to a generic message when the error body is not in the standard shape', async () => {
    server.use(http.get('*/api/ping', () => new HttpResponse('boom', { status: 500 })))

    await expect(apiFetch('/api/ping')).rejects.toMatchObject({ status: 500, message: 'Request failed (500)' })
  })
})
