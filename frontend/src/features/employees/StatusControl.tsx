import Alert from '@mui/material/Alert'
import Button from '@mui/material/Button'
import Dialog from '@mui/material/Dialog'
import DialogActions from '@mui/material/DialogActions'
import DialogContent from '@mui/material/DialogContent'
import DialogContentText from '@mui/material/DialogContentText'
import DialogTitle from '@mui/material/DialogTitle'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { updateEmployee, type Employee } from '../../api/employees'
import { employeeKey } from './useEmployee'

type Props = { employee: Employee; onChanged: (message: string) => void }

/** Deactivate (after confirming) or reactivate an employee. Employees are never deleted, so history is kept. */
export default function StatusControl({ employee, onChanged }: Props) {
  const queryClient = useQueryClient()
  const [confirming, setConfirming] = useState(false)

  const change = useMutation({
    mutationFn: (status: Employee['status']) => updateEmployee(employee.id, { employee: { status } }),
    onSuccess: (updated) => {
      queryClient.setQueryData(employeeKey(String(employee.id)), updated)
      void queryClient.invalidateQueries({ queryKey: ['employees'] })
      setConfirming(false)
      onChanged(updated.status === 'active' ? 'Employee reactivated' : 'Employee deactivated')
    },
  })

  if (employee.status === 'inactive') {
    return (
      <Button variant="outlined" onClick={() => change.mutate('active')} disabled={change.isPending}>
        Reactivate
      </Button>
    )
  }

  return (
    <>
      <Button variant="outlined" color="warning" onClick={() => setConfirming(true)}>
        Deactivate
      </Button>
      <Dialog open={confirming} onClose={() => setConfirming(false)} aria-labelledby="deactivate-title">
        <DialogTitle id="deactivate-title">Deactivate {employee.full_name}?</DialogTitle>
        <DialogContent>
          <DialogContentText>
            They are no longer counted in pay statistics. Their salary history is kept, and you can reactivate them at any time.
          </DialogContentText>
          {change.error && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {change.error.message}
            </Alert>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirming(false)} disabled={change.isPending}>
            Cancel
          </Button>
          <Button color="warning" variant="contained" onClick={() => change.mutate('inactive')} disabled={change.isPending}>
            Deactivate
          </Button>
        </DialogActions>
      </Dialog>
    </>
  )
}
