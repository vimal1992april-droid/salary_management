import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import CircularProgress from '@mui/material/CircularProgress'
import Paper from '@mui/material/Paper'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent, type ReactNode } from 'react'
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom'
import { ApiError } from '../../api/client'
import { createEmployee, updateEmployee, type Employee } from '../../api/employees'
import { todayIso } from '../../lib/date'
import {
  EMPTY_VALUES, fromServerErrors, toCreatePayload, toUpdatePayload, validateEmployee, valuesFromEmployee,
  type EmployeeErrors, type EmployeeValues,
} from './employeeForm'
import { useLookups } from './useDirectory'
import { employeeKey, useEmployee } from './useEmployee'

type Option = { value: string; label: string }

function Select({
  label, value, options, error, onChange,
}: { label: string; value: string; options: Option[]; error?: string; onChange: (value: string) => void }) {
  return (
    <TextField
      select
      label={label}
      value={value}
      onChange={(event) => onChange(event.target.value)}
      error={Boolean(error)}
      helperText={error}
      fullWidth
      margin="normal"
      slotProps={{ select: { native: true }, inputLabel: { shrink: true } }}
    >
      <option value="">Choose…</option>
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </TextField>
  )
}

function EmployeeForm({ employee }: { employee?: Employee }) {
  const mode = employee ? 'edit' : 'create'
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const lookups = useLookups()
  const today = todayIso()

  const [values, setValues] = useState<EmployeeValues>(employee ? valuesFromEmployee(employee) : EMPTY_VALUES)
  const [clientErrors, setClientErrors] = useState<EmployeeErrors>({})

  const save = useMutation({
    mutationFn: () => (employee ? updateEmployee(employee.id, toUpdatePayload(values)) : createEmployee(toCreatePayload(values))),
    onSuccess: (saved) => {
      queryClient.setQueryData(employeeKey(String(saved.id)), saved)
      void queryClient.invalidateQueries({ queryKey: ['employees'] })
      navigate(`/employees/${saved.id}`, { state: { notice: mode === 'create' ? 'Employee added' : 'Employee updated' } })
    },
  })

  // A 422 carries a message per field; anything else (or messages with no field) is shown above the form.
  const validation = save.error instanceof ApiError && save.error.status === 422 ? fromServerErrors(save.error.details) : undefined
  const generalErrors = validation ? validation.other : save.error ? [save.error.message] : []
  const errorFor = (field: keyof EmployeeValues) => clientErrors[field] ?? validation?.fields[field]

  // Editing a field ends what was said about it: its own message goes, and so does anything the server said.
  const set = (field: keyof EmployeeValues) => (value: string) => {
    setValues((previous) => ({ ...previous, [field]: value }))
    setClientErrors(({ [field]: _edited, ...rest }) => rest)
    save.reset()
  }
  const text = (field: keyof EmployeeValues, label: string, extra: { type?: string; helper?: ReactNode } = {}) => (
    <TextField
      label={label}
      type={extra.type}
      value={values[field]}
      onChange={(event) => set(field)(event.target.value)}
      error={Boolean(errorFor(field))}
      helperText={errorFor(field) ?? extra.helper}
      fullWidth
      margin="normal"
      slotProps={extra.type === 'date' ? { inputLabel: { shrink: true }, htmlInput: { max: today } } : undefined}
    />
  )

  const countries = (lookups.data?.countries ?? []).map((country) => ({ value: String(country.id), label: country.name }))
  const departments = (lookups.data?.departments ?? []).map((department) => ({ value: String(department.id), label: department.name }))
  const jobTitles = (lookups.data?.job_titles ?? []).map((title) => ({ value: String(title.id), label: title.name }))
  const currency = lookups.data?.countries.find((country) => String(country.id) === values.countryId)?.currency_code

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    const errors = validateEmployee(values, { mode, today })
    setClientErrors(errors)
    if (Object.keys(errors).length === 0) save.mutate()
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        {employee ? `Edit ${employee.full_name}` : 'Add employee'}
      </Typography>
      <Paper component="form" variant="outlined" noValidate onSubmit={handleSubmit} sx={{ p: 3, maxWidth: 640 }}>
        {generalErrors.length > 0 && (
          <Alert severity="error" sx={{ mb: 1 }}>
            {generalErrors.join(' ')}
          </Alert>
        )}

        {employee ? (
          <Box sx={{ mb: 1 }}>
            <Typography variant="caption" color="text.secondary" component="div">
              Employee number
            </Typography>
            <Typography>{employee.employee_number}</Typography>
          </Box>
        ) : (
          text('employeeNumber', 'Employee number')
        )}
        {text('firstName', 'First name')}
        {text('lastName', 'Last name')}
        {text('email', 'Email', { type: 'email' })}
        <Select label="Country" value={values.countryId} options={countries} error={errorFor('countryId')} onChange={set('countryId')} />
        <Select label="Department" value={values.departmentId} options={departments} error={errorFor('departmentId')} onChange={set('departmentId')} />
        <Select label="Job title" value={values.jobTitleId} options={jobTitles} error={errorFor('jobTitleId')} onChange={set('jobTitleId')} />
        {text('hireDate', 'Hire date', { type: 'date' })}

        {employee ? (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
            The salary is changed from the employee's page, so that every change is recorded with its date and reason.
          </Typography>
        ) : (
          text('salary', 'Starting salary', {
            helper: currency ? `Paid in ${currency}` : 'Paid in the currency of the country you choose',
          })
        )}

        <Box sx={{ display: 'flex', gap: 1, mt: 3 }}>
          <Button type="submit" variant="contained" disabled={save.isPending}>
            {save.isPending ? 'Saving…' : employee ? 'Save changes' : 'Add employee'}
          </Button>
          <Button component={RouterLink} to={employee ? `/employees/${employee.id}` : '/employees'}>
            Cancel
          </Button>
        </Box>
      </Paper>
    </Box>
  )
}

/** Adds an employee (/employees/new) or edits one (/employees/:id/edit). */
export default function EmployeeFormPage() {
  const { id } = useParams()
  const employee = useEmployee(id ?? '', Boolean(id))

  if (!id) return <EmployeeForm />

  if (employee.isPending) {
    return (
      <Box sx={{ display: 'grid', placeItems: 'center', py: 8 }}>
        <CircularProgress />
      </Box>
    )
  }

  if (employee.isError) {
    const notFound = employee.error instanceof ApiError && employee.error.status === 404
    return notFound ? (
      <>
        <Typography variant="h4" component="h1" gutterBottom>
          Employee not found
        </Typography>
        <Button component={RouterLink} to="/employees">
          Back to employees
        </Button>
      </>
    ) : (
      <Alert severity="error">Could not load this employee: {employee.error.message}</Alert>
    )
  }

  return <EmployeeForm key={employee.data.id} employee={employee.data} />
}
