import { apiFetch } from './client'

export type User = { id: number; email: string }
export type Credentials = { email: string; password: string }

export const getSession = () => apiFetch<{ user: User }>('/api/session').then((body) => body.user)

export const signIn = (credentials: Credentials) =>
  apiFetch<{ user: User }>('/api/session', { method: 'POST', json: credentials }).then((body) => body.user)

export const signOut = () => apiFetch<void>('/api/session', { method: 'DELETE' })
