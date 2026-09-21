import { describe, expect, it } from 'vitest'
import { formatDate, formatMoney, formatNumber } from './format'

describe('formatMoney', () => {
  it('formats a whole amount in its own currency with no decimals', () => {
    expect(formatMoney('90000.0', 'USD')).toBe('$90,000')
    expect(formatMoney('5104900.0', 'INR')).toBe('₹5,104,900')
    expect(formatMoney('11000000.0', 'JPY')).toBe('¥11,000,000')
  })

  it('keeps the cents when there are some', () => {
    expect(formatMoney('12345.67', 'USD')).toBe('$12,345.67')
    expect(formatMoney('12345.5', 'EUR')).toBe('€12,345.50')
  })

  it('shows a dash instead of NaN when the amount is missing or not a number', () => {
    expect(formatMoney(undefined, 'USD')).toBe('—')
    expect(formatMoney('abc', 'USD')).toBe('—')
  })
})

describe('formatDate', () => {
  it('formats an ISO date as day, month and year, whatever the time zone', () => {
    expect(formatDate('2022-03-01')).toBe('1 Mar 2022')
    expect(formatDate('2026-12-31')).toBe('31 Dec 2026')
  })

  it('shows a dash for a missing or invalid date', () => {
    expect(formatDate(undefined)).toBe('—')
    expect(formatDate('not a date')).toBe('—')
  })
})

describe('formatNumber', () => {
  it('groups thousands', () => {
    expect(formatNumber(10000)).toBe('10,000')
    expect(formatNumber(0)).toBe('0')
  })
})
