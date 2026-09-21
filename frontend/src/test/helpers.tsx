import { render } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { MemoryRouter } from 'react-router-dom'
import App from '../App'
import { Providers } from '../providers'
import { createQueryClient } from '../queryClient'
import { server } from './server'

export const hr = { id: 1, email: 'hr@acme.example' }

/** The session endpoint answers as a signed-in HR manager. */
export function signedIn(user = hr) {
  server.use(http.get('*/api/session', () => HttpResponse.json({ user })))
}

/** The session endpoint answers 401, as when nobody is signed in. */
export function signedOut() {
  server.use(
    http.get('*/api/session', () =>
      HttpResponse.json({ error: { code: 'unauthenticated', message: 'Please sign in to continue' } }, { status: 401 }),
    ),
  )
}

/** Renders the whole app at `route`, with a query client that never retries so failures show up at once. */
export function renderApp(route = '/') {
  const queryClient = createQueryClient({ retry: false })
  const utils = render(
    <Providers queryClient={queryClient}>
      <MemoryRouter initialEntries={[route]}>
        <App />
      </MemoryRouter>
    </Providers>,
  )
  return { queryClient, ...utils }
}
