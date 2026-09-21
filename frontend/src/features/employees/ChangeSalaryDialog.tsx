import Alert from '@mui/material/Alert'
import Button from '@mui/material/Button'
import Dialog from '@mui/material/Dialog'
import DialogActions from '@mui/material/DialogActions'
import DialogContent from '@mui/material/DialogContent'
import DialogTitle from '@mui/material/DialogTitle'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { ApiError } from '../../api/client'
import type { Employee } from '../../api/employees'
import { createSalaryChange } from '../../api/salaryChanges'
import { todayIso } from '../../lib/date'
import { formatMoney } from '../../lib/format'
import {
  fromServerErrors, toPayload, validateSalaryChange, MAX_REASON_LENGTH, type SalaryChangeErrors, type SalaryChangeValues,
} from './salaryChangeForm'
import { employeeKey, salaryHistoryKey } from './useEmployee'
import { useLookups } from './useDirectory'

type Props = { employee: Employee; onClose: () => void; onSaved: () => void }

/** A form to record a new salary: what it becomes, in which currency, from when and why. */
export default function ChangeSalaryDialog({ employee, onClose, onSaved }: Props) {
  const queryClient = useQueryClient()
  const lookups = useLookups()
  const today = todayIso()
  const { amount, currency } = employee.salary

  const [values, setValues] = useState<SalaryChangeValues>({ amount: '', currency, effectiveOn: today, reason: '' })
  const [clientErrors, setClientErrors] = useState<SalaryChangeErrors>({})

  const save = useMutation({
    mutationFn: () => createSalaryChange(employee.id, toPayload(values)),
    onSuccess: ({ employee: updated }) => {
      queryClient.setQueryData(employeeKey(String(employee.id)), updated)
      void queryClient.invalidateQueries({ queryKey: salaryHistoryKey(String(employee.id)) })
      void queryClient.invalidateQueries({ queryKey: ['employees'] }) // the directory shows salaries too
      onSaved()
    },
  })

  // A 422 carries a message per field; anything else (or messages with no field) is shown above the form.
  const validation = save.error instanceof ApiError && save.error.status === 422 ? fromServerErrors(save.error.details) : undefined
  const serverErrors = validation?.fields ?? {}
  const generalErrors = validation ? validation.other : save.error ? [save.error.message] : []
  const errorFor = (field: keyof SalaryChangeValues) => clientErrors[field] ?? serverErrors[field]

  const currencies = lookups.data?.currencies ?? [{ code: currency, name: currency, rate_to_usd: '', rate_as_of: '' }]

  function set(field: keyof SalaryChangeValues, value: string) {
    setValues((previous) => ({ ...previous, [field]: value }))
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    const errors = validateSalaryChange(values, { current: { amount, currency }, hireDate: employee.hire_date, today })
    setClientErrors(errors)
    if (Object.keys(errors).length === 0) save.mutate()
  }

  return (
    <Dialog open onClose={save.isPending ? undefined : onClose} fullWidth maxWidth="sm" aria-labelledby="change-salary-title">
      <form onSubmit={handleSubmit} noValidate>
        <DialogTitle id="change-salary-title">Change salary</DialogTitle>
        <DialogContent>
          <Typography variant="subtitle1">{employee.full_name}</Typography>
          <Typography color="text.secondary" gutterBottom>
            Current salary: {formatMoney(amount, currency)}
          </Typography>

          {generalErrors.length > 0 && (
            <Alert severity="error" sx={{ mb: 1 }}>
              {generalErrors.join(' ')}
            </Alert>
          )}

          <TextField
            label="New salary"
            value={values.amount}
            onChange={(event) => set('amount', event.target.value)}
            error={Boolean(errorFor('amount'))}
            helperText={errorFor('amount') ?? 'Per year, before tax'}
            fullWidth
            margin="normal"
            autoFocus
            slotProps={{ htmlInput: { inputMode: 'decimal' } }}
          />
          <TextField
            select
            label="Currency"
            value={values.currency}
            onChange={(event) => set('currency', event.target.value)}
            error={Boolean(errorFor('currency'))}
            helperText={errorFor('currency')}
            fullWidth
            margin="normal"
            slotProps={{ select: { native: true }, inputLabel: { shrink: true } }}
          >
            {currencies.map((option) => (
              <option key={option.code} value={option.code}>
                {option.code === option.name ? option.code : `${option.code} · ${option.name}`}
              </option>
            ))}
          </TextField>
          <TextField
            label="Effective date"
            type="date"
            value={values.effectiveOn}
            onChange={(event) => set('effectiveOn', event.target.value)}
            error={Boolean(errorFor('effectiveOn'))}
            helperText={errorFor('effectiveOn')}
            fullWidth
            margin="normal"
            slotProps={{ inputLabel: { shrink: true }, htmlInput: { min: employee.hire_date, max: today } }}
          />
          <TextField
            label="Reason"
            value={values.reason}
            onChange={(event) => set('reason', event.target.value)}
            error={Boolean(errorFor('reason'))}
            helperText={errorFor('reason') ?? `${values.reason.length}/${MAX_REASON_LENGTH}`}
            fullWidth
            margin="normal"
            multiline
            minRows={2}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={onClose} disabled={save.isPending}>
            Cancel
          </Button>
          <Button type="submit" variant="contained" disabled={save.isPending}>
            {save.isPending ? 'Saving…' : 'Save change'}
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  )
}
