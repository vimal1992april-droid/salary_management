import type { FieldErrors } from '../../api/client'
import { cleanAmount, isPositiveAmount } from '../../lib/amount'
import { formatDate } from '../../lib/format'

export type SalaryChangeValues = { amount: string; currency: string; effectiveOn: string; reason: string }
export type SalaryChangeErrors = Partial<Record<keyof SalaryChangeValues, string>>

type Context = {
  current: { amount: string; currency: string }
  hireDate: string
  /** Today as YYYY-MM-DD; passed in so the rules stay pure and testable. */
  today: string
}

export const MAX_REASON_LENGTH = 500

/** Checks the form the way the API will, so the user hears about a problem before anything is sent. */
export function validateSalaryChange(values: SalaryChangeValues, { current, hireDate, today }: Context): SalaryChangeErrors {
  const errors: SalaryChangeErrors = {}

  const amount = cleanAmount(values.amount)
  if (amount === '') {
    errors.amount = 'Enter the new salary'
  } else if (!isPositiveAmount(amount)) {
    errors.amount = 'Enter an amount greater than zero'
  } else if (Number(amount) === Number(current.amount) && values.currency === current.currency) {
    errors.amount = 'This is the same as the current salary'
  }

  if (!values.effectiveOn) {
    errors.effectiveOn = 'Choose the date it takes effect'
  } else if (values.effectiveOn > today) {
    errors.effectiveOn = 'The date cannot be in the future'
  } else if (values.effectiveOn < hireDate) {
    errors.effectiveOn = `The date cannot be before the hire date (${formatDate(hireDate)})`
  }

  if (values.reason.trim() === '') {
    errors.reason = 'Give a reason for the change'
  } else if (values.reason.length > MAX_REASON_LENGTH) {
    errors.reason = `The reason must be ${MAX_REASON_LENGTH} characters or fewer`
  }

  return errors
}

/** The request body for POST /api/employees/:id/salary_changes. */
export function toPayload(values: SalaryChangeValues) {
  return {
    salary_change: {
      new_amount: cleanAmount(values.amount),
      currency_code: values.currency,
      effective_on: values.effectiveOn,
      reason: values.reason.trim(),
    },
  }
}

const FIELD_FOR_SERVER_KEY: Record<string, keyof SalaryChangeValues> = {
  new_amount: 'amount',
  previous_amount: 'amount',
  new_currency: 'currency',
  new_currency_code: 'currency',
  effective_on: 'effectiveOn',
  reason: 'reason',
}

const capitalize = (text: string) => text.charAt(0).toUpperCase() + text.slice(1)

/** Sorts a 422's messages into those that belong beside a field and those that do not; none are dropped. */
export function fromServerErrors(details: FieldErrors | undefined) {
  const fields: SalaryChangeErrors = {}
  const other: string[] = []

  for (const [key, messages] of Object.entries(details ?? {})) {
    const field = FIELD_FOR_SERVER_KEY[key]
    if (field) {
      fields[field] = messages.map(capitalize).join('. ')
    } else {
      other.push(...messages.map((message) => capitalize(`${key.replaceAll('_', ' ')} ${message}`)))
    }
  }
  return { fields, other }
}
