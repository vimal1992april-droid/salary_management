import Chip from '@mui/material/Chip'
import Link from '@mui/material/Link'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import Typography from '@mui/material/Typography'
import { Link as RouterLink } from 'react-router-dom'
import { formatMoney, formatNumber } from '../../lib/format'
import { Loading, Section, SectionError } from './Section'
import { useOutliers } from './useInsights'

/** People paid outside the usual range for their peers, with what those peers earn. Amounts are in local currency. */
export default function OutliersSection() {
  const outliers = useOutliers()

  return (
    <Section title="Pay outliers">
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Compared with people who have the same job title in the same country (groups of five or more). The expected range
        is worked out from how pay is spread in that group, and those furthest outside it are listed first.
      </Typography>
      {outliers.isPending && <Loading />}
      {outliers.isError && <SectionError what="the outliers" error={outliers.error} onRetry={() => void outliers.refetch()} />}
      {outliers.data?.length === 0 && <Typography color="text.secondary">Nobody is paid outside their peer group&apos;s range.</Typography>}
      {outliers.data && outliers.data.length > 0 && (
        <Table size="small" aria-label="Pay outliers">
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Job title</TableCell>
              <TableCell>Country</TableCell>
              <TableCell align="right">Salary</TableCell>
              <TableCell align="right">Peers</TableCell>
              <TableCell align="right">Peer median</TableCell>
              <TableCell align="right">Expected range</TableCell>
              <TableCell />
            </TableRow>
          </TableHead>
          <TableBody>
            {outliers.data.map(({ employee, direction, peer_count, peer_median, fences }) => {
              const currency = employee.salary.currency
              return (
                <TableRow key={employee.id} hover>
                  <TableCell>
                    <Link component={RouterLink} to={`/employees/${employee.id}`} underline="hover">
                      {employee.full_name}
                    </Link>
                  </TableCell>
                  <TableCell>{employee.job_title.name}</TableCell>
                  <TableCell>{employee.country.name}</TableCell>
                  <TableCell align="right">{formatMoney(employee.salary.amount, currency)}</TableCell>
                  <TableCell align="right">{formatNumber(peer_count)}</TableCell>
                  <TableCell align="right">{formatMoney(peer_median, currency)}</TableCell>
                  <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                    {`${formatMoney(fences.lower, currency)} – ${formatMoney(fences.upper, currency)}`}
                  </TableCell>
                  <TableCell>
                    <Chip
                      size="small"
                      variant="outlined"
                      color={direction === 'above' ? 'warning' : 'info'}
                      label={direction === 'above' ? 'Above range' : 'Below range'}
                    />
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      )}
    </Section>
  )
}
