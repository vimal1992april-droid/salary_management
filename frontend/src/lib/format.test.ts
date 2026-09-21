import { describe, expect, it } from 'vitest'
import { formatDate, formatMoney, formatNumber, formatPercentChange, formatUsd } from './format'

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

describe('formatPercentChange', () => {
  it('shows a rise with a plus and a fall with a minus, to one decimal', () => {
    expect(formatPercentChange('80000', '90000')).toBe('+12.5%')
    expect(formatPercentChange('90000', '80000')).toBe('-11.1%')
  })

  it('drops the decimal for a whole percentage', () => {
    expect(formatPercentChange('100000', '110000')).toBe('+10%')
  })

  it('is a dash when there is nothing sensible to compare', () => {
    expect(formatPercentChange('0', '100')).toBe('—')
    expect(formatPercentChange('abc', '100')).toBe('—')
    expect(formatPercentChange('100', undefined)).toBe('—')
  })
})

describe('formatUsd', () => {
  it('rounds a USD figure to whole dollars, which is enough for statistics and totals', () => {
    expect(formatUsd('84486.13')).toBe('$84,486')
    expect(formatUsd('804054518.91')).toBe('$804,054,519')
    expect(formatUsd('0.4')).toBe('$0')
  })

  it('shows a dash when there is no figure', () => {
    expect(formatUsd(undefined)).toBe('—')
    expect(formatUsd(null)).toBe('—')
    expect(formatUsd('abc')).toBe('—')
  })
})
