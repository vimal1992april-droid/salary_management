import type { FieldErrors } from '../../api/client'
import type { Employee } from '../../api/employees'
import { cleanAmount, isPositiveAmount } from '../../lib/amount'

export type EmployeeValues = {
  employeeNumber: string
  firstName: string
  lastName: string
  email: string
  countryId: string
  departmentId: string
  jobTitleId: string
  hireDate: string
  salary: string
}
export type EmployeeErrors = Partial<Record<keyof EmployeeValues, string>>

export const EMPTY_VALUES: EmployeeValues = {
  employeeNumber: '', firstName: '', lastName: '', email: '',
  countryId: '', departmentId: '', jobTitleId: '', hireDate: '', salary: '',
}

/** The form's starting values for an existing employee. The salary is not editable here, so it stays empty. */
export function valuesFromEmployee(employee: Employee): EmployeeValues {
  return {
    employeeNumber: employee.employee_number,
    firstName: employee.first_name,
    lastName: employee.last_name,
    email: employee.email,
    countryId: String(employee.country.id),
    departmentId: String(employee.department.id),
    jobTitleId: String(employee.job_title.id),
    hireDate: employee.hire_date,
    salary: '',
  }
}

type Context = { mode: 'create' | 'edit'; today: string }

/** Checks the form the way the API will, so the user hears about a problem before anything is sent. */
export function validateEmployee(values: EmployeeValues, { mode, today }: Context): EmployeeErrors {
  const errors: EmployeeErrors = {}
  const blank = (value: string) => value.trim() === ''

  if (mode === 'create' && blank(values.employeeNumber)) errors.employeeNumber = 'Enter an employee number'
  if (blank(values.firstName)) errors.firstName = 'Enter a first name'
  if (blank(values.lastName)) errors.lastName = 'Enter a last name'

  if (blank(values.email)) errors.email = 'Enter an email address'
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.email.trim())) errors.email = 'Enter a valid email address'

  if (blank(values.countryId)) errors.countryId = 'Choose a country'
  if (blank(values.departmentId)) errors.departmentId = 'Choose a department'
  if (blank(values.jobTitleId)) errors.jobTitleId = 'Choose a job title'

  if (blank(values.hireDate)) errors.hireDate = 'Enter the hire date'
  else if (values.hireDate > today) errors.hireDate = 'The hire date cannot be in the future'

  if (mode === 'create') {
    const salary = cleanAmount(values.salary)
    if (salary === '') errors.salary = 'Enter the starting salary'
    else if (!isPositiveAmount(salary)) errors.salary = 'Enter an amount greater than zero'
  }

  return errors
}

function personalFields(values: EmployeeValues) {
  return {
    first_name: values.firstName.trim(),
    last_name: values.lastName.trim(),
    email: values.email.trim(),
    country_id: values.countryId,
    department_id: values.departmentId,
    job_title_id: values.jobTitleId,
    hire_date: values.hireDate,
  }
}

/** The body for POST /api/employees. No currency: the server uses the chosen country's. */
export function toCreatePayload(values: EmployeeValues) {
  return {
    employee: {
      employee_number: values.employeeNumber.trim(),
      ...personalFields(values),
      salary_amount: cleanAmount(values.salary),
    },
  }
}

/** The body for PATCH /api/employees/:id: only what the API lets change (never salary, currency or number). */
export function toUpdatePayload(values: EmployeeValues) {
  return { employee: personalFields(values) }
}

const FIELD_FOR_SERVER_KEY: Record<string, keyof EmployeeValues> = {
  employee_number: 'employeeNumber',
  first_name: 'firstName',
  last_name: 'lastName',
  email: 'email',
  country: 'countryId',
  department: 'departmentId',
  job_title: 'jobTitleId',
  hire_date: 'hireDate',
  salary_amount: 'salary',
}

const capitalize = (text: string) => text.charAt(0).toUpperCase() + text.slice(1)

/** Sorts a 422's messages into those that belong beside a field and those that do not; none are dropped. */
export function fromServerErrors(details: FieldErrors | undefined) {
  const fields: EmployeeErrors = {}
  const other: string[] = []

  for (const [key, messages] of Object.entries(details ?? {})) {
    const field = FIELD_FOR_SERVER_KEY[key]
    if (field) fields[field] = messages.map(capitalize).join('. ')
    else other.push(...messages.map((message) => capitalize(`${key.replaceAll('_', ' ')} ${message}`)))
  }
  return { fields, other }
}
