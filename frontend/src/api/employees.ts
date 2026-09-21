import { apiFetch } from './client'
import { toQueryString, type QueryValue } from './query'

/** Amounts arrive as strings so no precision is lost; `usd` is the value converted at the static rate. */
export type Salary = { amount: string; currency: string; usd: string }

export type Employee = {
  id: number
  employee_number: string
  first_name: string
  last_name: string
  full_name: string
  email: string
  hire_date: string
  status: 'active' | 'inactive'
  salary: Salary
  country: { id: number; name: string; iso_code: string }
  department: { id: number; name: string }
  job_title: { id: number; name: string; level: number }
}

export type EmployeeList = {
  data: Employee[]
  meta: { page: number; per_page: number; total: number; total_pages: number }
}

/** The directory's query parameters, named as the API names them. */
export type DirectoryParams = {
  q?: string
  country_id?: string
  department_id?: string
  job_title_id?: string
  status?: string
  sort?: string
  direction?: string
  page?: number
  per_page?: number
}

export const listEmployees = (params: DirectoryParams) =>
  apiFetch<EmployeeList>(`/api/employees${toQueryString(params as Record<string, QueryValue>)}`)

/** Where to download the CSV of the current filters: every match, so without the page. */
export function exportUrl({ page: _page, per_page: _perPage, ...filters }: DirectoryParams): string {
  return `/api/employees/export${toQueryString(filters as Record<string, QueryValue>)}`
}

export const getEmployee = (id: string | number) =>
  apiFetch<{ data: Employee }>(`/api/employees/${id}`).then((body) => body.data)

/** The fields of an employee that can be sent to the API; every value is a string, as typed in a form. */
export type EmployeeInput = Record<string, string>

export const createEmployee = (body: { employee: EmployeeInput }) =>
  apiFetch<{ data: Employee }>('/api/employees', { method: 'POST', json: body }).then((result) => result.data)

export const updateEmployee = (id: string | number, body: { employee: EmployeeInput }) =>
  apiFetch<{ data: Employee }>(`/api/employees/${id}`, { method: 'PATCH', json: body }).then((result) => result.data)
