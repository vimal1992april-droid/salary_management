import { apiFetch } from './client'
import { toQueryString } from './query'
import type { Employee } from './employees'

export type Overview = {
  headcount: number
  countries: number
  departments: number
  payroll_usd: string
  average_salary_usd: string | null
  median_salary_usd: string | null
  rates_as_of: string | null
}

export type GroupBy = 'country' | 'department' | 'job_title'

/** Pay in USD for one country, department or job title. */
export type PayStats = {
  group: { id: number; name: string }
  headcount: number
  min: string
  p25: string
  median: string
  p75: string
  max: string
  mean: string
}

export type Distribution = {
  min: string | null
  max: string | null
  buckets: { from: string; to: string; count: number }[]
}

/** Someone paid outside the usual range for their peers (same job title, same country). */
export type Outlier = {
  employee: Employee
  direction: 'above' | 'below'
  peer_count: number
  peer_median: string
  fences: { lower: string; upper: string }
  deviation: string
}

const get = <T>(path: string, params: Record<string, string | number> = {}) =>
  apiFetch<{ data: T }>(`/api/insights/${path}${toQueryString(params)}`).then((body) => body.data)

export const getOverview = () => get<Overview>('overview')
export const getPayStats = (groupBy: GroupBy) => get<PayStats[]>('salary_stats', { group_by: groupBy })
export const getDistribution = (bucketCount = 12) => get<Distribution>('distribution', { bucket_count: bucketCount })
export const getTopEarners = (direction: 'asc' | 'desc', limit = 10) => get<Employee[]>('top_earners', { direction, limit })
export const getOutliers = (limit = 25) => get<Outlier[]>('outliers', { limit })
