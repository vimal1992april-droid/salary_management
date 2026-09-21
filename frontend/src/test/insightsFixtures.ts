import type { Distribution, Outlier, Overview, PayStats } from '../api/insights'
import { makeEmployee } from './fixtures'

export const overview: Overview = {
  headcount: 9517,
  countries: 8,
  departments: 8,
  payroll_usd: '804054518.91',
  average_salary_usd: '84486.13',
  median_salary_usd: '78495.86',
  rates_as_of: '2026-01-01',
}

const row = (id: number, name: string, headcount: number, values: string[]): PayStats => ({
  group: { id, name },
  headcount,
  min: values[0], p25: values[1], median: values[2], p75: values[3], max: values[4], mean: values[5],
})

export const statsByGroup: Record<string, PayStats[]> = {
  country: [
    row(2, 'India', 2099, ['13442.4', '25079.4', '31760.4', '41191.8', '110042.4', '34000.0']),
    row(1, 'United States', 2881, ['48500.0', '81900.0', '109700.0', '140300.0', '323600.0', '112000.0']),
  ],
  department: [row(1, 'Engineering', 3300, ['30000.0', '70000.0', '100000.0', '130000.0', '300000.0', '105000.0'])],
  job_title: [row(9, 'Staff Engineer', 800, ['90000.0', '140000.0', '170000.0', '200000.0', '330000.0', '175000.0'])],
}

export const distribution: Distribution = {
  min: '13442.4',
  max: '449753.0',
  buckets: [
    { from: '13442.4', to: '49801.62', count: 2746 },
    { from: '49801.62', to: '86160.83', count: 2411 },
  ],
}

const usdEmployee = (id: number, name: string, usd: string) =>
  makeEmployee({ id, full_name: name, salary: { amount: usd, currency: 'USD', usd } })

export const highestPaid = [usdEmployee(10, 'Diego Miller', '449753.0'), usdEmployee(11, 'Yuki Hansen', '347345.0')]
export const lowestPaid = [usdEmployee(20, 'Yuki Murphy', '13442.4'), usdEmployee(21, 'Fatima Taylor', '13674.0')]

export const outliers: Outlier[] = [
  {
    employee: makeEmployee({
      id: 500, full_name: 'Diego Miller',
      job_title: { id: 5, name: 'Engineering Manager', level: 4 }, country: { id: 6, name: 'Canada', iso_code: 'CA' },
      salary: { amount: '616100.0', currency: 'CAD', usd: '449753.0' },
    }),
    direction: 'above', peer_count: 30, peer_median: '255050.0', fences: { lower: '218975.0', upper: '293375.0' }, deviation: '1.27',
  },
  {
    employee: makeEmployee({
      id: 600, full_name: 'Yuki Murphy',
      job_title: { id: 8, name: 'Support Specialist', level: 1 }, country: { id: 2, name: 'India', iso_code: 'IN' },
      salary: { amount: '1000000.0', currency: 'INR', usd: '12000.0' },
    }),
    direction: 'below', peer_count: 90, peer_median: '1500000.0', fences: { lower: '1100000.0', upper: '1900000.0' }, deviation: '0.09',
  },
]
