import { apiFetch } from './client'
import type { Employee } from './employees'

export type SalaryAmount = { amount: string; currency: string }

/** One entry of an employee's salary history. `changed_by` is null for imported history. */
export type SalaryChange = {
  id: number
  effective_on: string
  reason: string
  previous_salary: SalaryAmount
  new_salary: SalaryAmount
  changed_by: { id: number; email: string } | null
  created_at: string
}

/** The history, newest first. */
export const listSalaryChanges = (employeeId: string | number) =>
  apiFetch<{ data: SalaryChange[] }>(`/api/employees/${employeeId}/salary_changes`).then((body) => body.data)

export type SalaryChangeRequest = {
  salary_change: { new_amount: string; currency_code: string; effective_on: string; reason: string }
}

/** Records a change. The response carries the updated employee, so the page can refresh in one round trip. */
export const createSalaryChange = (employeeId: string | number, request: SalaryChangeRequest) =>
  apiFetch<{ data: SalaryChange; employee: Employee }>(`/api/employees/${employeeId}/salary_changes`, {
    method: 'POST',
    json: request,
  })
