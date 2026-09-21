const DASH = '—'

const moneyFormats = new Map<string, Intl.NumberFormat>()

function moneyFormat(currency: string, fractionDigits: number) {
  const key = `${currency}:${fractionDigits}`
  let format = moneyFormats.get(key)
  if (!format) {
    format = new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    })
    moneyFormats.set(key, format)
  }
  return format
}

/** "$90,000" or "₹5,104,900": whole amounts without decimals, the cents kept when there are some. */
export function formatMoney(amount: string | undefined, currency: string): string {
  if (amount === undefined || amount.trim() === '') return DASH
  const value = Number(amount)
  if (!Number.isFinite(value)) return DASH
  return moneyFormat(currency, Number.isInteger(value) ? 0 : 2).format(value)
}

const dateFormat = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' })

/** "1 Mar 2022" from an ISO date, independent of the browser's time zone. */
export function formatDate(isoDate: string | undefined): string {
  if (!isoDate || !/^\d{4}-\d{2}-\d{2}/.test(isoDate)) return DASH
  const date = new Date(isoDate)
  return Number.isNaN(date.getTime()) ? DASH : dateFormat.format(date)
}

const numberFormat = new Intl.NumberFormat('en-US')

export function formatNumber(value: number): string {
  return numberFormat.format(value)
}

/** "+12.5%", "-11.1%" or "+10%": how much a value changed, to one decimal; a dash when it cannot be compared. */
export function formatPercentChange(previous: string | undefined, next: string | undefined): string {
  if (!previous || !next) return DASH
  const before = Number(previous)
  const after = Number(next)
  if (!Number.isFinite(before) || !Number.isFinite(after) || before === 0) return DASH

  const percent = Math.round(((after - before) / before) * 1000) / 10
  const text = Number.isInteger(percent) ? String(percent) : percent.toFixed(1)
  return `${percent > 0 ? '+' : ''}${text}%`
}

/** A USD figure rounded to whole dollars, which is precise enough for totals and statistics. */
export function formatUsd(amount: string | null | undefined): string {
  if (amount === null || amount === undefined) return DASH
  const value = Number(amount)
  return Number.isFinite(value) ? formatMoney(String(Math.round(value)), 'USD') : DASH
}
