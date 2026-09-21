export type FieldErrors = Record<string, string[]>

type ErrorBody = { error?: { code?: string; message?: string; details?: FieldErrors } }

/** A failed API call. `status` is 0 when the server could not be reached at all. */
export class ApiError extends Error {
  readonly status: number
  /** The server's machine-readable error code, when it sent one. */
  readonly code: string | undefined
  /** Per-field validation messages from a 422, keyed by field name. */
  readonly details: FieldErrors | undefined

  constructor(status: number, message: string, code?: string, details?: FieldErrors) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
    this.details = details
  }
}

/** Like `RequestInit`, but `json` is sent as the JSON body. */
export type ApiRequest = Omit<RequestInit, 'body'> & { json?: unknown }

async function toApiError(response: Response): Promise<ApiError> {
  const fallback = `Request failed (${response.status})`
  try {
    const { error } = (await response.json()) as ErrorBody
    return new ApiError(response.status, error?.message ?? fallback, error?.code, error?.details)
  } catch {
    return new ApiError(response.status, fallback)
  }
}

/**
 * Calls the Rails API and returns the parsed JSON body (undefined for 204 No Content).
 * Any failure, including an unreachable server, is thrown as an `ApiError`.
 */
export async function apiFetch<T>(path: string, { json, headers, ...init }: ApiRequest = {}): Promise<T> {
  const requestHeaders = new Headers(headers)
  requestHeaders.set('Accept', 'application/json')
  if (json !== undefined) requestHeaders.set('Content-Type', 'application/json')

  let response: Response
  try {
    response = await fetch(path, {
      ...init,
      headers: requestHeaders,
      body: json === undefined ? undefined : JSON.stringify(json),
    })
  } catch {
    throw new ApiError(0, 'Could not reach the server', 'network_error')
  }

  if (!response.ok) throw await toApiError(response)
  if (response.status === 204) return undefined as T
  return (await response.json()) as T
}
