import { render, screen } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import App from './App'
import { server } from './test/server'

describe('App', () => {
  it('shows the API status once the health check succeeds', async () => {
    server.use(
      http.get('*/api/health', () => HttpResponse.json({ status: 'ok', database: true, rails: '8.1.3' })),
    )

    render(<App />)

    expect(screen.getByText('Checking API…')).toBeInTheDocument()
    expect(await screen.findByText('API ok · Rails 8.1.3 · database connected')).toBeInTheDocument()
  })

  it('says so when the database is down', async () => {
    server.use(
      http.get('*/api/health', () => HttpResponse.json({ status: 'ok', database: false, rails: '8.1.3' })),
    )

    render(<App />)

    expect(await screen.findByText(/database down/)).toBeInTheDocument()
  })

  it('reports that the API is unreachable when the request fails', async () => {
    server.use(http.get('*/api/health', () => new HttpResponse(null, { status: 503 })))

    render(<App />)

    expect(await screen.findByText('API unreachable: Request failed (503)')).toBeInTheDocument()
  })
})
