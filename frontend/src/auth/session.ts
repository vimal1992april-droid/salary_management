import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ApiError } from '../api/client'
import { getSession, signIn, signOut, type User } from '../api/session'

export const sessionKey = ['session'] as const

/** The signed-in user, or null when nobody is signed in. Other failures are real errors, not "signed out". */
async function fetchSession(): Promise<User | null> {
  try {
    return await getSession()
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) return null
    throw error
  }
}

export function useSession() {
  return useQuery({ queryKey: sessionKey, queryFn: fetchSession, staleTime: 5 * 60_000 })
}

export function useSignIn() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: signIn,
    onSuccess: (user) => queryClient.setQueryData(sessionKey, user),
  })
}

export function useSignOut() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: signOut,
    onSuccess: () => {
      // Nothing fetched for the previous user may outlive their session.
      queryClient.removeQueries({ predicate: (query) => query.queryKey[0] !== sessionKey[0] })
      queryClient.setQueryData(sessionKey, null)
    },
  })
}
