import { describe, expect, it } from 'vitest'
import { DEFAULT_STATE, parseDirectoryState, toApiParams, toUrlParams } from './directoryState'

const parse = (query: string) => parseDirectoryState(new URLSearchParams(query))

describe('parseDirectoryState', () => {
  it('uses the defaults for an empty query: active employees, by name, first page of 25', () => {
    expect(parse('')).toEqual({
      q: '', countryId: '', departmentId: '', jobTitleId: '', status: 'active',
      sort: 'name', direction: 'asc', page: 1, perPage: 25,
    })
    expect(DEFAULT_STATE).toEqual(parse(''))
  })

  it('reads every field from the query string', () => {
    expect(parse('q=priya&country_id=6&department_id=2&job_title_id=9&status=inactive&sort=salary&direction=desc&page=3&per_page=50')).toEqual({
      q: 'priya', countryId: '6', departmentId: '2', jobTitleId: '9', status: 'inactive',
      sort: 'salary', direction: 'desc', page: 3, perPage: 50,
    })
  })

  it('reads "all" as every status', () => {
    expect(parse('status=all').status).toBe('all')
  })

  it('falls back to the defaults for values it does not recognise', () => {
    const state = parse('status=retired&sort=password_digest&direction=sideways&page=-4&per_page=7')

    expect([state.status, state.sort, state.direction, state.page, state.perPage]).toEqual(['active', 'name', 'asc', 1, 25])
  })

  it('treats a non-numeric page as the first page', () => {
    expect(parse('page=abc').page).toBe(1)
    expect(parse('page=0').page).toBe(1)
  })
})

describe('toUrlParams', () => {
  it('leaves defaults out, so an untouched directory has a clean URL', () => {
    expect(toUrlParams(DEFAULT_STATE).toString()).toBe('')
  })

  it('writes what differs from the defaults', () => {
    const params = toUrlParams({ ...DEFAULT_STATE, q: 'priya', countryId: '6', status: 'all', sort: 'hire_date', direction: 'desc', page: 2, perPage: 100 })

    expect(Object.fromEntries(params)).toEqual({
      q: 'priya', country_id: '6', status: 'all', sort: 'hire_date', direction: 'desc', page: '2', per_page: '100',
    })
  })

  it('round-trips through the query string', () => {
    const state = { ...DEFAULT_STATE, departmentId: '4', jobTitleId: '12', status: 'inactive' as const, sort: 'country' as const, page: 5 }

    expect(parseDirectoryState(toUrlParams(state))).toEqual(state)
  })
})

describe('toApiParams', () => {
  it('sends the status only when it narrows the list', () => {
    expect(toApiParams({ ...DEFAULT_STATE, status: 'active' }).status).toBe('active')
    expect(toApiParams({ ...DEFAULT_STATE, status: 'all' }).status).toBeUndefined()
  })

  it('sends the search, filters, sort and page as the API names them', () => {
    expect(
      toApiParams({ ...DEFAULT_STATE, q: 'priya', countryId: '6', departmentId: '2', jobTitleId: '9', sort: 'salary', direction: 'desc', page: 3, perPage: 50 }),
    ).toEqual({
      q: 'priya', country_id: '6', department_id: '2', job_title_id: '9', status: 'active',
      sort: 'salary', direction: 'desc', page: 3, per_page: 50,
    })
  })

  it('leaves out filters that are empty', () => {
    const params = toApiParams(DEFAULT_STATE)

    expect(params.q).toBeUndefined()
    expect(params.country_id).toBeUndefined()
  })
})
