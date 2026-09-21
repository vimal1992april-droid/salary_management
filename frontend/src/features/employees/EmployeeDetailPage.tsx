import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Chip from '@mui/material/Chip'
import CircularProgress from '@mui/material/CircularProgress'
import Grid from '@mui/material/Grid'
import Paper from '@mui/material/Paper'
import Typography from '@mui/material/Typography'
import { Link as RouterLink, useParams } from 'react-router-dom'
import { ApiError } from '../../api/client'
import type { Employee } from '../../api/employees'
import { formatDate, formatMoney } from '../../lib/format'
import SalaryHistory from './SalaryHistory'
import { useEmployee } from './useEmployee'

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Box>
      <Typography variant="caption" color="text.secondary" component="div">
        {label}
      </Typography>
      <Typography component="div">{children}</Typography>
    </Box>
  )
}

function BackLink() {
  return (
    <Button component={RouterLink} to="/employees" size="small" sx={{ mb: 1 }}>
      Back to employees
    </Button>
  )
}

function Profile({ employee }: { employee: Employee }) {
  const { amount, currency, usd } = employee.salary

  return (
    <Grid container spacing={3}>
      <Grid size={{ xs: 12, md: 7 }}>
        <Paper variant="outlined" sx={{ p: 3 }}>
          <Typography variant="h6" component="h2" gutterBottom>
            Profile
          </Typography>
          <Grid container spacing={2}>
            <Grid size={6}><Field label="Employee number">{employee.employee_number}</Field></Grid>
            <Grid size={6}><Field label="Email">{employee.email}</Field></Grid>
            <Grid size={6}><Field label="Country">{employee.country.name}</Field></Grid>
            <Grid size={6}><Field label="Department">{employee.department.name}</Field></Grid>
            <Grid size={6}><Field label="Job title">{employee.job_title.name}</Field></Grid>
            <Grid size={6}><Field label="Hired">{formatDate(employee.hire_date)}</Field></Grid>
          </Grid>
        </Paper>
      </Grid>
      <Grid size={{ xs: 12, md: 5 }}>
        <Paper variant="outlined" sx={{ p: 3 }}>
          <Typography variant="h6" component="h2" gutterBottom>
            Current salary
          </Typography>
          <Typography variant="h4" component="p">
            {formatMoney(amount, currency)}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            per year
          </Typography>
          {currency !== 'USD' && (
            <Typography variant="body2" color="text.secondary">
              ≈ {formatMoney(String(Math.round(Number(usd))), 'USD')} at the current rate
            </Typography>
          )}
        </Paper>
      </Grid>
    </Grid>
  )
}

export default function EmployeeDetailPage() {
  const { id = '' } = useParams()
  const employee = useEmployee(id)

  if (employee.isPending) {
    return (
      <Box sx={{ display: 'grid', placeItems: 'center', py: 8 }}>
        <CircularProgress />
      </Box>
    )
  }

  if (employee.isError) {
    if (employee.error instanceof ApiError && employee.error.status === 404) {
      return (
        <>
          <BackLink />
          <Typography variant="h4" component="h1" gutterBottom>
            Employee not found
          </Typography>
          <Typography color="text.secondary">There is no employee with this number.</Typography>
        </>
      )
    }
    return (
      <>
        <BackLink />
        <Alert
          severity="error"
          action={
            <Button color="inherit" size="small" onClick={() => void employee.refetch()}>
              Try again
            </Button>
          }
        >
          Could not load this employee: {employee.error.message}
        </Alert>
      </>
    )
  }

  const { data } = employee
  return (
    <>
      <BackLink />
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 3 }}>
        <Typography variant="h4" component="h1">
          {data.full_name}
        </Typography>
        <Chip
          size="small"
          label={data.status === 'active' ? 'Active' : 'Inactive'}
          color={data.status === 'active' ? 'success' : 'default'}
          variant="outlined"
        />
      </Box>

      <Profile employee={data} />

      <Paper variant="outlined" sx={{ p: 3, mt: 3 }}>
        <Typography variant="h6" component="h2" gutterBottom>
          Salary history
        </Typography>
        <SalaryHistory employeeId={id} />
      </Paper>
    </>
  )
}
