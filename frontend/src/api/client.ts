type ErrorBody = { error?: { code?: string; message?: string } }

/** A non-2xx API response. `code` is the server's machine-readable error code, when it sent one. */
export class ApiError extends Error {
  readonly status: number
  readonly code: string | undefined

  constructor(status: number, message: string, code?: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
  }
}

async function toApiError(response: Response): Promise<ApiError> {
  const fallback = `Request failed (${response.status})`
  try {
    const { error } = (await response.json()) as ErrorBody
    return new ApiError(response.status, error?.message ?? fallback, error?.code)
  } catch {
    return new ApiError(response.status, fallback)
  }
}

/** Fetches a JSON resource from the Rails API, throwing an `ApiError` for any non-2xx response. */
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: { Accept: 'application/json', ...init?.headers },
  })
  if (!response.ok) throw await toApiError(response)
  return (await response.json()) as T
}
