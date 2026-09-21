import Link from '@mui/material/Link'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import ToggleButton from '@mui/material/ToggleButton'
import ToggleButtonGroup from '@mui/material/ToggleButtonGroup'
import Typography from '@mui/material/Typography'
import { useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import type { GroupBy } from '../../api/insights'
import { formatNumber, formatUsd } from '../../lib/format'
import { Loading, Section, SectionError } from './Section'
import { usePayStats } from './useInsights'

const GROUPS: { value: GroupBy; label: string; filter: string }[] = [
  { value: 'country', label: 'Country', filter: 'country_id' },
  { value: 'department', label: 'Department', filter: 'department_id' },
  { value: 'job_title', label: 'Job title', filter: 'job_title_id' },
]

/** How pay is spread within each country, department or job title; each group links to the directory filtered to it. */
export default function PayStatsSection() {
  const [groupBy, setGroupBy] = useState<GroupBy>('country')
  const group = GROUPS.find((option) => option.value === groupBy)!
  const stats = usePayStats(groupBy)

  return (
    <Section
      title={`Pay by ${group.label.toLowerCase()}`}
      actions={
        <ToggleButtonGroup
          exclusive
          size="small"
          value={groupBy}
          aria-label="Group pay by"
          onChange={(_event, value: GroupBy | null) => value && setGroupBy(value)}
        >
          {GROUPS.map((option) => (
            <ToggleButton key={option.value} value={option.value}>
              {option.label}
            </ToggleButton>
          ))}
        </ToggleButtonGroup>
      }
    >
      {stats.isPending && <Loading />}
      {stats.isError && <SectionError what="the pay statistics" error={stats.error} onRetry={() => void stats.refetch()} />}
      {stats.data?.length === 0 && <Typography color="text.secondary">No active employees to report on.</Typography>}
      {stats.data && stats.data.length > 0 && (
        <Table size="small" aria-label={`Pay by ${group.label.toLowerCase()}`}>
          <TableHead>
            <TableRow>
              <TableCell>{group.label}</TableCell>
              <TableCell align="right">Headcount</TableCell>
              <TableCell align="right">Lowest</TableCell>
              <TableCell align="right">25th percentile</TableCell>
              <TableCell align="right">Median</TableCell>
              <TableCell align="right">75th percentile</TableCell>
              <TableCell align="right">Highest</TableCell>
              <TableCell align="right">Average</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {stats.data.map((row) => (
              <TableRow key={row.group.id} hover>
                <TableCell>
                  <Link component={RouterLink} to={`/employees?${group.filter}=${row.group.id}`} underline="hover">
                    {row.group.name}
                  </Link>
                </TableCell>
                <TableCell align="right">{formatNumber(row.headcount)}</TableCell>
                <TableCell align="right">{formatUsd(row.min)}</TableCell>
                <TableCell align="right">{formatUsd(row.p25)}</TableCell>
                <TableCell align="right">{formatUsd(row.median)}</TableCell>
                <TableCell align="right">{formatUsd(row.p75)}</TableCell>
                <TableCell align="right">{formatUsd(row.max)}</TableCell>
                <TableCell align="right">{formatUsd(row.mean)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </Section>
  )
}
