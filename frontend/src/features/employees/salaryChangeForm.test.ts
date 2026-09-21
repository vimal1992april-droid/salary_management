import { describe, expect, it } from 'vitest'
import { fromServerErrors, toPayload, validateSalaryChange, type SalaryChangeValues } from './salaryChangeForm'

const context = { current: { amount: '90000.0', currency: 'USD' }, hireDate: '2022-03-01', today: '2026-09-21' }
const valid: SalaryChangeValues = { amount: '110000', currency: 'USD', effectiveOn: '2026-09-01', reason: 'Annual review' }

const errorsFor = (changes: Partial<SalaryChangeValues>) => validateSalaryChange({ ...valid, ...changes }, context)

describe('validateSalaryChange', () => {
  it('accepts a complete, sensible change', () => {
    expect(validateSalaryChange(valid, context)).toEqual({})
  })

  it('asks for the new salary, and for a number above zero', () => {
    expect(errorsFor({ amount: '' }).amount).toBe('Enter the new salary')
    expect(errorsFor({ amount: '   ' }).amount).toBe('Enter the new salary')
    for (const amount of ['0', '-5', 'abc', '1e']) {
      expect(errorsFor({ amount }).amount).toBe('Enter an amount greater than zero')
    }
  })

  it('accepts amounts written with thousands separators or spaces', () => {
    expect(errorsFor({ amount: '110,000' })).toEqual({})
    expect(errorsFor({ amount: '110 000.50' })).toEqual({})
  })

  it('rejects a change that leaves the salary as it is, but not the same amount in another currency', () => {
    expect(errorsFor({ amount: '90000' }).amount).toBe('This is the same as the current salary')
    expect(errorsFor({ amount: '90,000.00' }).amount).toBe('This is the same as the current salary')
    expect(errorsFor({ amount: '90000', currency: 'EUR' })).toEqual({})
  })

  it('asks for the date it takes effect, which cannot be in the future or before the hire date', () => {
    expect(errorsFor({ effectiveOn: '' }).effectiveOn).toBe('Choose the date it takes effect')
    expect(errorsFor({ effectiveOn: '2026-09-22' }).effectiveOn).toBe('The date cannot be in the future')
    expect(errorsFor({ effectiveOn: '2026-09-21' })).toEqual({})
    expect(errorsFor({ effectiveOn: '2022-02-28' }).effectiveOn).toBe('The date cannot be before the hire date (1 Mar 2022)')
    expect(errorsFor({ effectiveOn: '2022-03-01' })).toEqual({})
  })

  it('asks for a reason of at most 500 characters', () => {
    expect(errorsFor({ reason: '' }).reason).toBe('Give a reason for the change')
    expect(errorsFor({ reason: '   ' }).reason).toBe('Give a reason for the change')
    expect(errorsFor({ reason: 'x'.repeat(501) }).reason).toBe('The reason must be 500 characters or fewer')
    expect(errorsFor({ reason: 'x'.repeat(500) })).toEqual({})
  })

  it('reports every problem at once', () => {
    expect(Object.keys(validateSalaryChange({ amount: '', currency: 'USD', effectiveOn: '', reason: '' }, context)).sort()).toEqual([
      'amount', 'effectiveOn', 'reason',
    ])
  })
})

describe('toPayload', () => {
  it('builds the request body the API expects, with the amount cleaned up and the reason trimmed', () => {
    expect(toPayload({ amount: ' 110,000.50 ', currency: 'GBP', effectiveOn: '2026-09-01', reason: '  Promotion ' })).toEqual({
      salary_change: { new_amount: '110000.50', currency_code: 'GBP', effective_on: '2026-09-01', reason: 'Promotion' },
    })
  })
})

describe('fromServerErrors', () => {
  it('shows the server\'s messages next to the fields they belong to', () => {
    const { fields, other } = fromServerErrors({
      new_amount: ['must differ from the current salary'],
      effective_on: ['cannot be in the future'],
      reason: ["can't be blank"],
      new_currency: ['must exist'],
    })

    expect(fields).toEqual({
      amount: 'Must differ from the current salary',
      effectiveOn: 'Cannot be in the future',
      reason: "Can't be blank",
      currency: 'Must exist',
    })
    expect(other).toEqual([])
  })

  it('keeps messages about anything else, so nothing the server said is lost', () => {
    const { fields, other } = fromServerErrors({ employee: ['is inactive'] })

    expect(fields).toEqual({})
    expect(other).toEqual(['Employee is inactive'])
  })

  it('copes with no details at all', () => {
    expect(fromServerErrors(undefined)).toEqual({ fields: {}, other: [] })
  })
})
