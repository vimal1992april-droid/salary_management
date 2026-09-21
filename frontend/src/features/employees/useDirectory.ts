import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router-dom'
import { listEmployees } from '../../api/employees'
import { getLookups } from '../../api/lookups'
import { parseDirectoryState, toApiParams, toUrlParams, type DirectoryState } from './directoryState'

/** The directory's view, read from and written to the URL. Any change but a page change returns to page one. */
export function useDirectoryState() {
  const [searchParams, setSearchParams] = useSearchParams()
  const state = useMemo(() => parseDirectoryState(searchParams), [searchParams])

  const update = useCallback(
    (changes: Partial<DirectoryState>) => {
      setSearchParams((current) => {
        const next = { ...parseDirectoryState(current), ...changes }
        if (!('page' in changes)) next.page = 1
        return toUrlParams(next)
      })
    },
    [setSearchParams],
  )

  return { state, update }
}

export function useEmployees(state: DirectoryState) {
  const params = toApiParams(state)
  // Keep showing the previous page while the next one loads, so paging does not flash.
  return useQuery({ queryKey: ['employees', params], queryFn: () => listEmployees(params), placeholderData: keepPreviousData })
}

export function useLookups() {
  return useQuery({ queryKey: ['lookups'], queryFn: getLookups, staleTime: 10 * 60_000 })
}
