import type { Employee, EmployeeList } from '../api/employees'
import type { Lookups } from '../api/lookups'

let nextId = 1

/** An employee as the API returns them; override only what the test cares about. */
export function makeEmployee(overrides: Partial<Employee> = {}): Employee {
  const id = overrides.id ?? nextId++
  return {
    id,
    employee_number: `E${String(id).padStart(5, '0')}`,
    first_name: 'Asha',
    last_name: 'Verma',
    full_name: 'Asha Verma',
    email: 'asha.verma@acme.example',
    hire_date: '2022-03-01',
    status: 'active',
    salary: { amount: '90000.0', currency: 'USD', usd: '90000.0' },
    country: { id: 1, name: 'United States', iso_code: 'US' },
    department: { id: 1, name: 'Engineering' },
    job_title: { id: 1, name: 'Software Engineer II', level: 2 },
    ...overrides,
  }
}

/** A page of the directory; `meta` defaults describe a single page holding everything given. */
export function pageOf(employees: Employee[], meta: Partial<EmployeeList['meta']> = {}): EmployeeList {
  return { data: employees, meta: { page: 1, per_page: 25, total: employees.length, total_pages: 1, ...meta } }
}

export const lookups: Lookups = {
  countries: [
    { id: 1, name: 'United States', iso_code: 'US', currency_code: 'USD' },
    { id: 2, name: 'India', iso_code: 'IN', currency_code: 'INR' },
  ],
  departments: [
    { id: 1, name: 'Engineering' },
    { id: 2, name: 'Sales' },
  ],
  job_titles: [
    { id: 1, name: 'Software Engineer II', level: 2 },
    { id: 2, name: 'Account Executive', level: 2 },
  ],
  currencies: [
    { code: 'USD', name: 'US Dollar', rate_to_usd: '1.0', rate_as_of: '2026-01-01' },
    { code: 'INR', name: 'Indian Rupee', rate_to_usd: '0.012', rate_as_of: '2026-01-01' },
  ],
}
