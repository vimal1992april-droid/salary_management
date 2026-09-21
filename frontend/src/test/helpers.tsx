import { render } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { MemoryRouter, useLocation } from 'react-router-dom'
import type { EmployeeList } from '../api/employees'
import App from '../App'
import { Providers } from '../providers'
import { createQueryClient } from '../queryClient'
import { lookups, pageOf } from './fixtures'
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

/**
 * Serves the lookups and the employee directory. `respond` decides each answer from the request's query
 * parameters; every request is recorded in the returned array, so tests can assert what the UI asked for.
 */
export function mockDirectory(respond: (params: URLSearchParams) => EmployeeList | Response = () => pageOf([])) {
  const requests: URLSearchParams[] = []
  server.use(
    http.get('*/api/lookups', () => HttpResponse.json(lookups)),
    http.get('*/api/employees', ({ request }) => {
      const params = new URL(request.url).searchParams
      requests.push(params)
      const result = respond(params)
      return result instanceof Response ? result : HttpResponse.json(result)
    }),
  )
  return requests
}

/** Shows the router's current location, so tests can check the URL the app ended up at. */
function LocationSpy() {
  const location = useLocation()
  return <output data-testid="location">{`${location.pathname}${location.search}`}</output>
}

/** Renders the whole app at `route`, with a query client that never retries so failures show up at once. */
export function renderApp(route = '/') {
  const queryClient = createQueryClient({ retry: false })
  const utils = render(
    <Providers queryClient={queryClient}>
      <MemoryRouter initialEntries={[route]}>
        <App />
        <LocationSpy />
      </MemoryRouter>
    </Providers>,
  )
  return { queryClient, ...utils }
}
