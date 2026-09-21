import Chip from '@mui/material/Chip'
import Link from '@mui/material/Link'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import TableSortLabel from '@mui/material/TableSortLabel'
import Typography from '@mui/material/Typography'
import { Link as RouterLink } from 'react-router-dom'
import type { Employee } from '../../api/employees'
import { formatDate, formatMoney } from '../../lib/format'
import type { DirectoryState, SortKey } from './directoryState'

type Column = { label: string; sort?: SortKey; align?: 'right' }

const COLUMNS: Column[] = [
  { label: 'Number', sort: 'employee_number' },
  { label: 'Name', sort: 'name' },
  { label: 'Email' },
  { label: 'Country', sort: 'country' },
  { label: 'Department', sort: 'department' },
  { label: 'Job title', sort: 'job_title' },
  { label: 'Hired', sort: 'hire_date' },
  { label: 'Salary', sort: 'salary', align: 'right' },
  { label: 'Status' },
]

function SalaryCell({ employee }: { employee: Employee }) {
  const { amount, currency, usd } = employee.salary
  return (
    <>
      <Typography variant="body2">{formatMoney(amount, currency)}</Typography>
      {currency !== 'USD' && (
        <Typography variant="caption" color="text.secondary">
          ≈ {formatMoney(String(Math.round(Number(usd))), 'USD')}
        </Typography>
      )}
    </>
  )
}

type Props = {
  employees: Employee[]
  sort: DirectoryState['sort']
  direction: DirectoryState['direction']
  onSort: (key: SortKey) => void
}

export default function EmployeeTable({ employees, sort, direction, onSort }: Props) {
  return (
    <Table size="small" aria-label="Employees">
      <TableHead>
        <TableRow>
          {COLUMNS.map((column) => (
            <TableCell
              key={column.label}
              align={column.align}
              sortDirection={column.sort && column.sort === sort ? direction : false}
              sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}
            >
              {column.sort ? (
                <TableSortLabel active={column.sort === sort} direction={column.sort === sort ? direction : 'asc'} onClick={() => onSort(column.sort!)}>
                  {column.label}
                </TableSortLabel>
              ) : (
                column.label
              )}
            </TableCell>
          ))}
        </TableRow>
      </TableHead>
      <TableBody>
        {employees.map((employee) => (
          <TableRow key={employee.id} hover>
            <TableCell>{employee.employee_number}</TableCell>
            <TableCell>
              <Link component={RouterLink} to={`/employees/${employee.id}`} underline="hover">
                {employee.full_name}
              </Link>
            </TableCell>
            <TableCell>{employee.email}</TableCell>
            <TableCell>{employee.country.name}</TableCell>
            <TableCell>{employee.department.name}</TableCell>
            <TableCell>{employee.job_title.name}</TableCell>
            <TableCell sx={{ whiteSpace: 'nowrap' }}>{formatDate(employee.hire_date)}</TableCell>
            <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
              <SalaryCell employee={employee} />
            </TableCell>
            <TableCell>
              <Chip
                size="small"
                label={employee.status === 'active' ? 'Active' : 'Inactive'}
                color={employee.status === 'active' ? 'success' : 'default'}
                variant="outlined"
              />
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
