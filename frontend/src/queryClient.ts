import { QueryCache, QueryClient } from '@tanstack/react-query'
import { ApiError } from './api/client'
import { sessionKey } from './auth/session'

type Options = {
  /** Retry requests that failed because the server could not be reached. Turned off in tests. */
  retry?: boolean
}

export function createQueryClient({ retry = true }: Options = {}) {
  const client: QueryClient = new QueryClient({
    queryCache: new QueryCache({
      // Any 401 means the session ended (expired, or signed out elsewhere): re-check it, and the auth
      // gate will send the user to the sign-in page.
      onError: (error) => {
        if (error instanceof ApiError && error.status === 401) {
          void client.invalidateQueries({ queryKey: sessionKey })
        }
      },
    }),
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        refetchOnWindowFocus: false,
        retry: retry ? (failures, error) => error instanceof ApiError && error.status === 0 && failures < 2 : false,
      },
    },
  })
  return client
}
