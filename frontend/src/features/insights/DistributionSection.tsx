import Box from '@mui/material/Box'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import Typography from '@mui/material/Typography'
import { lazy, Suspense } from 'react'
import { visuallyHidden } from '../../components/visuallyHidden'
import { formatNumber, formatUsd } from '../../lib/format'
import { Loading, Section, SectionError } from './Section'
import { useDistribution } from './useInsights'

// The chart library is large, so it is only fetched once there is a distribution to draw.
const DistributionChart = lazy(() => import('./DistributionChart'))

/** How many people fall in each pay band: a chart for the eye, and the same numbers as a table for everyone. */
export default function DistributionSection() {
  const distribution = useDistribution()
  const buckets = distribution.data?.buckets ?? []

  return (
    <Section title="Salary distribution">
      {distribution.isPending && <Loading />}
      {distribution.isError && (
        <SectionError what="the salary distribution" error={distribution.error} onRetry={() => void distribution.refetch()} />
      )}
      {distribution.data && buckets.length === 0 && <Typography color="text.secondary">No active employees to report on.</Typography>}
      {buckets.length > 0 && (
        <>
          <Suspense fallback={<Loading />}>
            <DistributionChart buckets={buckets} />
          </Suspense>
          <Box sx={visuallyHidden}>
            <Table aria-label="Salary distribution (USD)">
              <TableHead>
                <TableRow>
                  <TableCell>Pay band</TableCell>
                  <TableCell>Employees</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {buckets.map((bucket) => (
                  <TableRow key={bucket.from}>
                    <TableCell>{`${formatUsd(bucket.from)} – ${formatUsd(bucket.to)}`}</TableCell>
                    <TableCell>{formatNumber(bucket.count)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Box>
        </>
      )}
    </Section>
  )
}
