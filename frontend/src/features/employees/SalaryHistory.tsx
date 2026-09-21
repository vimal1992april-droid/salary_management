import Alert from '@mui/material/Alert'
import CircularProgress from '@mui/material/CircularProgress'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import Typography from '@mui/material/Typography'
import { formatDate, formatMoney, formatPercentChange } from '../../lib/format'
import { useSalaryHistory } from './useEmployee'

/** The employee's salary changes, newest first: when, what it was and became, why, and who recorded it. */
export default function SalaryHistory({ employeeId }: { employeeId: string }) {
  const history = useSalaryHistory(employeeId)

  if (history.isPending) return <CircularProgress size={24} aria-label="Loading the salary history" />
  if (history.isError) return <Alert severity="error">Could not load the salary history: {history.error.message}</Alert>
  if (history.data.length === 0) {
    return <Typography color="text.secondary">No salary changes have been recorded yet.</Typography>
  }

  return (
    <Table size="small" aria-label="Salary history">
      <TableHead>
        <TableRow>
          <TableCell>Effective</TableCell>
          <TableCell>Change</TableCell>
          <TableCell>Reason</TableCell>
          <TableCell>Recorded by</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {history.data.map((change) => {
          const { previous_salary: before, new_salary: after } = change
          // Amounts in two different currencies are not comparable, so no percentage is shown for those.
          const percent = before.currency === after.currency ? formatPercentChange(before.amount, after.amount) : '—'

          return (
            <TableRow key={change.id}>
              <TableCell sx={{ whiteSpace: 'nowrap' }}>{formatDate(change.effective_on)}</TableCell>
              <TableCell sx={{ whiteSpace: 'nowrap' }}>
                <span>{formatMoney(before.amount, before.currency)}</span> → <span>{formatMoney(after.amount, after.currency)}</span>{' '}
                <Typography component="span" variant="caption" color="text.secondary">
                  {percent}
                </Typography>
              </TableCell>
              <TableCell>{change.reason}</TableCell>
              <TableCell>{change.changed_by?.email ?? 'Imported'}</TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
