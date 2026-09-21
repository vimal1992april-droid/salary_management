import DownloadIcon from '@mui/icons-material/Download'
import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import LinearProgress from '@mui/material/LinearProgress'
import Paper from '@mui/material/Paper'
import TableContainer from '@mui/material/TableContainer'
import TablePagination from '@mui/material/TablePagination'
import Typography from '@mui/material/Typography'
import { exportUrl } from '../../api/employees'
import { formatNumber } from '../../lib/format'
import DirectoryFilters from './DirectoryFilters'
import { DEFAULT_STATE, PAGE_SIZES, toApiParams, type SortKey } from './directoryState'
import EmployeeTable from './EmployeeTable'
import { useDirectoryState, useEmployees, useLookups } from './useDirectory'

export default function EmployeesPage() {
  const { state, update } = useDirectoryState()
  const employees = useEmployees(state)
  const lookups = useLookups()

  function handleSort(key: SortKey) {
    update(state.sort === key ? { direction: state.direction === 'asc' ? 'desc' : 'asc' } : { sort: key, direction: 'asc' })
  }

  function clearFilters() {
    update({ q: '', countryId: '', departmentId: '', jobTitleId: '', status: DEFAULT_STATE.status })
  }

  const rows = employees.data?.data
  const total = employees.data?.meta.total ?? 0

  return (
    <>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h4" component="h1">
          Employees
        </Typography>
        <Button component="a" href={exportUrl(toApiParams(state))} variant="outlined" startIcon={<DownloadIcon />}>
          Export CSV
        </Button>
      </Box>

      <DirectoryFilters state={state} lookups={lookups.data} onChange={update} onClear={clearFilters} />

      {employees.isError && (
        <Alert
          severity="error"
          sx={{ mb: 2 }}
          action={
            <Button color="inherit" size="small" onClick={() => void employees.refetch()}>
              Try again
            </Button>
          }
        >
          Could not load employees: {employees.error.message}
        </Alert>
      )}

      <Paper variant="outlined">
        {employees.isFetching && <LinearProgress />}
        <TableContainer>
          <EmployeeTable employees={rows ?? []} sort={state.sort} direction={state.direction} onSort={handleSort} />
        </TableContainer>

        {rows?.length === 0 && (
          <Box sx={{ p: 4, textAlign: 'center' }}>
            <Typography color="text.secondary">No employees match these filters.</Typography>
          </Box>
        )}

        <TablePagination
          component="div"
          count={total}
          page={state.page - 1}
          rowsPerPage={state.perPage}
          rowsPerPageOptions={[...PAGE_SIZES]}
          onPageChange={(_event, page) => update({ page: page + 1 })}
          onRowsPerPageChange={(event) => update({ perPage: Number(event.target.value) })}
          labelRowsPerPage="Rows per page"
          labelDisplayedRows={({ from, to, count }) => `${formatNumber(from)}–${formatNumber(to)} of ${formatNumber(count)}`}
          slotProps={{ select: { native: true, inputProps: { 'aria-label': 'Rows per page' } } }}
        />
      </Paper>
    </>
  )
}
