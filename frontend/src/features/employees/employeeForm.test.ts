import { describe, expect, it } from 'vitest'
import { makeEmployee } from '../../test/fixtures'
import {
  EMPTY_VALUES, fromServerErrors, toCreatePayload, toUpdatePayload, validateEmployee, valuesFromEmployee, type EmployeeValues,
} from './employeeForm'

const valid: EmployeeValues = {
  employeeNumber: 'E90001', firstName: 'Nikhil', lastName: 'Rao', email: 'nikhil.rao@acme.example',
  countryId: '2', departmentId: '1', jobTitleId: '1', hireDate: '2026-05-01', salary: '120000',
}
const today = '2026-09-21'
const create = (changes: Partial<EmployeeValues>) => validateEmployee({ ...valid, ...changes }, { mode: 'create', today })
const edit = (changes: Partial<EmployeeValues>) => validateEmployee({ ...valid, ...changes }, { mode: 'edit', today })

describe('validateEmployee', () => {
  it('accepts a complete employee', () => {
    expect(create({})).toEqual({})
    expect(edit({})).toEqual({})
  })

  it('asks for each required field', () => {
    expect(validateEmployee({ ...EMPTY_VALUES }, { mode: 'create', today })).toEqual({
      employeeNumber: 'Enter an employee number',
      firstName: 'Enter a first name',
      lastName: 'Enter a last name',
      email: 'Enter an email address',
      countryId: 'Choose a country',
      departmentId: 'Choose a department',
      jobTitleId: 'Choose a job title',
      hireDate: 'Enter the hire date',
      salary: 'Enter the starting salary',
    })
  })

  it('treats a field of only spaces as empty', () => {
    expect(create({ firstName: '   ' }).firstName).toBe('Enter a first name')
  })

  it('checks that the email looks like an email', () => {
    for (const email of ['nikhil', 'nikhil@', '@acme.example', 'nikhil rao@acme.example']) {
      expect(create({ email }).email).toBe('Enter a valid email address')
    }
    expect(create({ email: '  nikhil.rao@acme.example ' })).toEqual({})
  })

  it('does not accept a hire date in the future', () => {
    expect(create({ hireDate: '2026-09-22' }).hireDate).toBe('The hire date cannot be in the future')
    expect(create({ hireDate: '2026-09-21' })).toEqual({})
  })

  it('needs a starting salary above zero, but only when creating', () => {
    for (const salary of ['0', '-1', 'abc']) {
      expect(create({ salary }).salary).toBe('Enter an amount greater than zero')
    }
    expect(create({ salary: '120,000' })).toEqual({})
    expect(edit({ salary: '' })).toEqual({})
  })

  it('does not ask for an employee number when editing, since it cannot change', () => {
    expect(edit({ employeeNumber: '' })).toEqual({})
  })
})

describe('the request bodies', () => {
  it('creates with everything, the salary cleaned up, and no currency: the server uses the country\'s', () => {
    expect(toCreatePayload({ ...valid, firstName: ' Nikhil ', salary: '120,000' })).toEqual({
      employee: {
        employee_number: 'E90001', first_name: 'Nikhil', last_name: 'Rao', email: 'nikhil.rao@acme.example',
        country_id: '2', department_id: '1', job_title_id: '1', hire_date: '2026-05-01', salary_amount: '120000',
      },
    })
  })

  it('updates only what the API allows to change: never the salary, currency or employee number', () => {
    const body = toUpdatePayload(valid)

    expect(Object.keys(body.employee).sort()).toEqual([
      'country_id', 'department_id', 'email', 'first_name', 'hire_date', 'job_title_id', 'last_name',
    ])
  })
})

describe('valuesFromEmployee', () => {
  it('fills the form from an existing employee, leaving the salary out', () => {
    const employee = makeEmployee({
      id: 7, employee_number: 'E00007', first_name: 'Asha', last_name: 'Verma', email: 'asha@acme.example', hire_date: '2022-03-01',
      country: { id: 2, name: 'India', iso_code: 'IN' }, department: { id: 3, name: 'Sales' }, job_title: { id: 4, name: 'Account Executive', level: 2 },
    })

    expect(valuesFromEmployee(employee)).toEqual({
      employeeNumber: 'E00007', firstName: 'Asha', lastName: 'Verma', email: 'asha@acme.example',
      countryId: '2', departmentId: '3', jobTitleId: '4', hireDate: '2022-03-01', salary: '',
    })
  })
})

describe('fromServerErrors', () => {
  it('shows the server\'s messages beside the right fields', () => {
    const { fields, other } = fromServerErrors({
      email: ['has already been taken'], employee_number: ['has already been taken'], first_name: ["can't be blank"],
      country: ['must exist'], hire_date: ['cannot be in the future'], salary_amount: ['must be greater than 0'],
    })

    expect(fields).toEqual({
      email: 'Has already been taken', employeeNumber: 'Has already been taken', firstName: "Can't be blank",
      countryId: 'Must exist', hireDate: 'Cannot be in the future', salary: 'Must be greater than 0',
    })
    expect(other).toEqual([])
  })

  it('keeps messages about anything else', () => {
    expect(fromServerErrors({ currency: ['must exist'] })).toEqual({ fields: {}, other: ['Currency must exist'] })
  })
})
