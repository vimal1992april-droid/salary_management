import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import type { Lookups } from '../../api/lookups'
import { hasActiveFilters, type DirectoryState, type StatusFilter } from './directoryState'
import SearchField from './SearchField'

type Option = { value: string; label: string }

function FilterSelect({
  label, value, options, disabled, onChange,
}: { label: string; value: string; options: Option[]; disabled?: boolean; onChange: (value: string) => void }) {
  return (
    <TextField
      select
      label={label}
      size="small"
      value={value}
      disabled={disabled}
      onChange={(event) => onChange(event.target.value)}
      sx={{ minWidth: 170 }}
      slotProps={{ select: { native: true }, inputLabel: { shrink: true } }}
    >
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </TextField>
  )
}

const STATUS_OPTIONS: Option[] = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'all', label: 'All statuses' },
]

type Props = {
  state: DirectoryState
  lookups: Lookups | undefined
  onChange: (changes: Partial<DirectoryState>) => void
  onClear: () => void
}

/** The search box and the filters, all driven by the directory's state in the URL. */
export default function DirectoryFilters({ state, lookups, onChange, onClear }: Props) {
  const loading = !lookups

  return (
    <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center', mb: 2 }}>
      <SearchField value={state.q} onSearch={(q) => onChange({ q })} />
      <FilterSelect
        label="Country"
        value={state.countryId}
        disabled={loading}
        onChange={(countryId) => onChange({ countryId })}
        options={[{ value: '', label: 'All countries' }, ...(lookups?.countries ?? []).map((c) => ({ value: String(c.id), label: c.name }))]}
      />
      <FilterSelect
        label="Department"
        value={state.departmentId}
        disabled={loading}
        onChange={(departmentId) => onChange({ departmentId })}
        options={[{ value: '', label: 'All departments' }, ...(lookups?.departments ?? []).map((d) => ({ value: String(d.id), label: d.name }))]}
      />
      <FilterSelect
        label="Job title"
        value={state.jobTitleId}
        disabled={loading}
        onChange={(jobTitleId) => onChange({ jobTitleId })}
        options={[{ value: '', label: 'All job titles' }, ...(lookups?.job_titles ?? []).map((t) => ({ value: String(t.id), label: t.name }))]}
      />
      <FilterSelect
        label="Status"
        value={state.status}
        onChange={(status) => onChange({ status: status as StatusFilter })}
        options={STATUS_OPTIONS}
      />
      {hasActiveFilters(state) && (
        <Button size="small" onClick={onClear}>
          Clear filters
        </Button>
      )}
    </Box>
  )
}
