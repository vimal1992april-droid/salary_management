import { apiFetch } from './client'

export type Lookups = {
  countries: { id: number; name: string; iso_code: string; currency_code: string }[]
  departments: { id: number; name: string }[]
  job_titles: { id: number; name: string; level: number }[]
  currencies: { code: string; name: string; rate_to_usd: string; rate_as_of: string }[]
}

export const getLookups = () => apiFetch<Lookups>('/api/lookups')
