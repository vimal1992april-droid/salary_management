import { render } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { MemoryRouter } from 'react-router-dom'
import type { Employee, EmployeeList } from '../api/employees'
import App from '../App'
import { Providers } from '../providers'
import { createQueryClient } from '../queryClient'
import { lookups, pageOf } from './fixtures'
import { distribution, highestPaid, lowestPaid, outliers, overview, statsByGroup } from './insightsFixtures'
import LocationSpy from './LocationSpy'
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

type InsightOverrides = Partial<Record<'overview' | 'stats' | 'distribution' | 'topEarners' | 'outliers', () => Response>>

/**
 * Serves every insight endpoint with the fixtures, and records each request the dashboard makes.
 * A section can be made to fail (or answer differently) by overriding its handler.
 */
export function mockInsights(overrides: InsightOverrides = {}) {
  const requests: URL[] = []
  const answer = (name: keyof InsightOverrides, body: unknown) => (overrides[name] ? overrides[name]!() : HttpResponse.json({ data: body }))

  server.use(
    http.get('*/api/insights/overview', ({ request }) => (requests.push(new URL(request.url)), answer('overview', overview))),
    http.get('*/api/insights/salary_stats', ({ request }) => {
      const url = new URL(request.url)
      requests.push(url)
      return answer('stats', statsByGroup[url.searchParams.get('group_by') ?? 'country'])
    }),
    http.get('*/api/insights/distribution', ({ request }) => (requests.push(new URL(request.url)), answer('distribution', distribution))),
    http.get('*/api/insights/top_earners', ({ request }) => {
      const url = new URL(request.url)
      requests.push(url)
      const list: Employee[] = url.searchParams.get('direction') === 'asc' ? lowestPaid : highestPaid
      return answer('topEarners', list)
    }),
    http.get('*/api/insights/outliers', ({ request }) => (requests.push(new URL(request.url)), answer('outliers', outliers))),
  )
  return requests
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
