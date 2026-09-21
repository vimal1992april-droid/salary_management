import { apiFetch } from './client'

export type Health = { status: string; database: boolean; rails: string }

export const getHealth = () => apiFetch<Health>('/api/health')
