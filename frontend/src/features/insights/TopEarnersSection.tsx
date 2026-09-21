import Link from '@mui/material/Link'
import Tab from '@mui/material/Tab'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import Tabs from '@mui/material/Tabs'
import { useState } from 'react'
import { Link as RouterLink } from 'react-router-dom'
import { formatUsd } from '../../lib/format'
import { Loading, Section, SectionError } from './Section'
import { useTopEarners } from './useInsights'

type Direction = 'desc' | 'asc'

/** The ten highest or lowest paid people, ranked by USD value so currencies compare fairly. */
export default function TopEarnersSection() {
  const [direction, setDirection] = useState<Direction>('desc')
  const earners = useTopEarners(direction)

  return (
    <Section title="Highest and lowest paid">
      <Tabs value={direction} onChange={(_event, value: Direction) => setDirection(value)} sx={{ mb: 1 }}>
        <Tab value="desc" label="Highest paid" />
        <Tab value="asc" label="Lowest paid" />
      </Tabs>
      {earners.isPending && <Loading />}
      {earners.isError && <SectionError what="the top earners" error={earners.error} onRetry={() => void earners.refetch()} />}
      {earners.data && (
        <Table size="small" aria-label={direction === 'desc' ? 'Highest paid' : 'Lowest paid'}>
          <TableHead>
            <TableRow>
              <TableCell>Name</TableCell>
              <TableCell>Job title</TableCell>
              <TableCell>Country</TableCell>
              <TableCell align="right">Salary (USD)</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {earners.data.map((employee) => (
              <TableRow key={employee.id} hover>
                <TableCell>
                  <Link component={RouterLink} to={`/employees/${employee.id}`} underline="hover">
                    {employee.full_name}
                  </Link>
                </TableCell>
                <TableCell>{employee.job_title.name}</TableCell>
                <TableCell>{employee.country.name}</TableCell>
                <TableCell align="right">{formatUsd(employee.salary.usd)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </Section>
  )
}
