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

  it('sends the json option as a JSON body with the right content type', async () => {
    let received: { body: unknown; contentType: string | null } | undefined
    server.use(
      http.post('*/api/things', async ({ request }) => {
        received = { body: await request.json(), contentType: request.headers.get('content-type') }
        return HttpResponse.json({ id: 1 }, { status: 201 })
      }),
    )

    await apiFetch('/api/things', { method: 'POST', json: { name: 'Asha' } })

    expect(received).toEqual({ body: { name: 'Asha' }, contentType: 'application/json' })
  })

  it('returns undefined for a response with no content', async () => {
    server.use(http.delete('*/api/things/1', () => new HttpResponse(null, { status: 204 })))

    await expect(apiFetch('/api/things/1', { method: 'DELETE' })).resolves.toBeUndefined()
  })

  it('exposes the per-field validation errors of a 422', async () => {
    server.use(
      http.post('*/api/things', () =>
        HttpResponse.json(
          { error: { code: 'validation_failed', message: 'Validation failed', details: { email: ['has already been taken'] } } },
          { status: 422 },
        ),
      ),
    )

    await expect(apiFetch('/api/things', { method: 'POST', json: {} })).rejects.toMatchObject({
      status: 422,
      code: 'validation_failed',
      details: { email: ['has already been taken'] },
    })
  })

  it('turns a network failure into an ApiError instead of a bare TypeError', async () => {
    server.use(http.get('*/api/ping', () => HttpResponse.error()))

    await expect(apiFetch('/api/ping')).rejects.toMatchObject({
      status: 0,
      code: 'network_error',
      message: 'Could not reach the server',
    })
  })
})
