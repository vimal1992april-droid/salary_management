import Alert from '@mui/material/Alert'
import Grid from '@mui/material/Grid'
import Paper from '@mui/material/Paper'
import Typography from '@mui/material/Typography'
import { useId } from 'react'
import { formatDate, formatNumber, formatUsd } from '../../lib/format'
import { useOverview } from './useInsights'

function Card({ label, value }: { label: string; value: string }) {
  const labelId = useId()
  return (
    <Paper role="group" aria-labelledby={labelId} variant="outlined" sx={{ p: 2.5 }}>
      <Typography id={labelId} variant="body2" color="text.secondary">
        {label}
      </Typography>
      <Typography variant="h4" component="p">
        {value}
      </Typography>
    </Paper>
  )
}

/** Headcount, payroll and typical salary for the whole organisation. */
export default function OverviewCards() {
  const overview = useOverview()

  if (overview.isError) {
    return <Alert severity="error">Could not load the overview: {overview.error.message}</Alert>
  }

  const data = overview.data
  const show = (value: string) => (data ? value : '…')

  return (
    <>
      <Grid container spacing={2}>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card label="Headcount" value={show(formatNumber(data?.headcount ?? 0))} />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card label="Annual payroll" value={show(formatUsd(data?.payroll_usd))} />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card label="Average salary" value={show(formatUsd(data?.average_salary_usd))} />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card label="Median salary" value={show(formatUsd(data?.median_salary_usd))} />
        </Grid>
      </Grid>
      {data && (
        <>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
            Active employees in {data.countries} countries and {data.departments} departments.
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {data.rates_as_of
              ? `Amounts are in USD, converted at exchange rates as of ${formatDate(data.rates_as_of)}.`
              : 'Amounts are in USD.'}
          </Typography>
        </>
      )}
    </>
  )
}
