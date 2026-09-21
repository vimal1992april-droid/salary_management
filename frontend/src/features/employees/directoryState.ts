import type { DirectoryParams } from '../../api/employees'

export const SORT_KEYS = ['name', 'employee_number', 'hire_date', 'salary', 'country', 'department', 'job_title'] as const
export type SortKey = (typeof SORT_KEYS)[number]
export type StatusFilter = 'active' | 'inactive' | 'all'
export const PAGE_SIZES = [10, 25, 50, 100] as const

/** Everything that defines a view of the directory. It lives in the URL, so views can be shared and refreshed. */
export type DirectoryState = {
  q: string
  countryId: string
  departmentId: string
  jobTitleId: string
  status: StatusFilter
  sort: SortKey
  direction: 'asc' | 'desc'
  page: number
  perPage: number
}

export const DEFAULT_STATE: DirectoryState = {
  q: '',
  countryId: '',
  departmentId: '',
  jobTitleId: '',
  status: 'active',
  sort: 'name',
  direction: 'asc',
  page: 1,
  perPage: 25,
}

function oneOf<T extends string>(value: string | null, allowed: readonly T[], fallback: T): T {
  return allowed.find((option) => option === value) ?? fallback
}

/** Reads a view from the query string; anything unrecognised falls back to the default. */
export function parseDirectoryState(search: URLSearchParams): DirectoryState {
  const page = Number(search.get('page'))
  const perPage = Number(search.get('per_page'))

  return {
    q: search.get('q') ?? DEFAULT_STATE.q,
    countryId: search.get('country_id') ?? DEFAULT_STATE.countryId,
    departmentId: search.get('department_id') ?? DEFAULT_STATE.departmentId,
    jobTitleId: search.get('job_title_id') ?? DEFAULT_STATE.jobTitleId,
    status: oneOf(search.get('status'), ['active', 'inactive', 'all'], DEFAULT_STATE.status),
    sort: oneOf(search.get('sort'), SORT_KEYS, DEFAULT_STATE.sort),
    direction: oneOf(search.get('direction'), ['asc', 'desc'], DEFAULT_STATE.direction),
    page: Number.isInteger(page) && page >= 1 ? page : DEFAULT_STATE.page,
    perPage: PAGE_SIZES.find((size) => size === perPage) ?? DEFAULT_STATE.perPage,
  }
}

/** The query string for a view, leaving out whatever is the default so an untouched directory has a clean URL. */
export function toUrlParams(state: DirectoryState): URLSearchParams {
  const params = new URLSearchParams()
  const set = (name: string, value: string | number, fallback: string | number) => {
    if (value !== fallback && value !== '') params.set(name, String(value))
  }

  set('q', state.q, DEFAULT_STATE.q)
  set('country_id', state.countryId, DEFAULT_STATE.countryId)
  set('department_id', state.departmentId, DEFAULT_STATE.departmentId)
  set('job_title_id', state.jobTitleId, DEFAULT_STATE.jobTitleId)
  set('status', state.status, DEFAULT_STATE.status)
  set('sort', state.sort, DEFAULT_STATE.sort)
  set('direction', state.direction, DEFAULT_STATE.direction)
  set('page', state.page, DEFAULT_STATE.page)
  set('per_page', state.perPage, DEFAULT_STATE.perPage)
  return params
}

/** The parameters to send to the API for a view. "All statuses" sends no status at all. */
export function toApiParams(state: DirectoryState): DirectoryParams {
  return {
    q: state.q || undefined,
    country_id: state.countryId || undefined,
    department_id: state.departmentId || undefined,
    job_title_id: state.jobTitleId || undefined,
    status: state.status === 'all' ? undefined : state.status,
    sort: state.sort,
    direction: state.direction,
    page: state.page,
    per_page: state.perPage,
  }
}

/** True when the view is narrowed by a search or filter, so "Clear filters" has something to do. */
export function hasActiveFilters(state: DirectoryState): boolean {
  return Boolean(state.q || state.countryId || state.departmentId || state.jobTitleId) || state.status !== DEFAULT_STATE.status
}
