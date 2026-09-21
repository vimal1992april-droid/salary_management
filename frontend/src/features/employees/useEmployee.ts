import { useQuery } from '@tanstack/react-query'
import { getEmployee } from '../../api/employees'
import { listSalaryChanges } from '../../api/salaryChanges'

export const employeeKey = (id: string) => ['employee', id] as const
export const salaryHistoryKey = (id: string) => ['employee', id, 'salary-changes'] as const

export function useEmployee(id: string, enabled = true) {
  return useQuery({ queryKey: employeeKey(id), queryFn: () => getEmployee(id), enabled })
}

export function useSalaryHistory(id: string) {
  return useQuery({ queryKey: salaryHistoryKey(id), queryFn: () => listSalaryChanges(id) })
}
