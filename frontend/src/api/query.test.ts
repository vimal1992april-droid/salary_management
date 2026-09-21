import { describe, expect, it } from 'vitest'
import { toQueryString } from './query'

describe('toQueryString', () => {
  it('builds a query string from the given parameters', () => {
    expect(toQueryString({ q: 'asha', page: 2 })).toBe('?q=asha&page=2')
  })

  it('leaves out empty, null and undefined values', () => {
    expect(toQueryString({ q: '', country_id: undefined, department_id: null, page: 1 })).toBe('?page=1')
  })

  it('keeps a value of zero and false', () => {
    expect(toQueryString({ page: 0, active: false })).toBe('?page=0&active=false')
  })

  it('escapes special characters', () => {
    expect(toQueryString({ q: 'a&b c' })).toBe('?q=a%26b+c')
  })

  it('is an empty string when there is nothing to send', () => {
    expect(toQueryString({})).toBe('')
    expect(toQueryString({ q: '' })).toBe('')
  })
})
