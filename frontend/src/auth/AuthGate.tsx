import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import CircularProgress from '@mui/material/CircularProgress'
import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useSession } from './session'

/** Renders the nested routes for a signed-in user, and sends everyone else to the sign-in page. */
export default function AuthGate() {
  const session = useSession()
  const location = useLocation()

  if (session.isPending) {
    return (
      <Box sx={{ display: 'grid', placeItems: 'center', minHeight: '100vh' }}>
        <CircularProgress />
      </Box>
    )
  }

  // A failed check is not the same as being signed out: say what happened and let the user retry.
  if (session.isError) {
    return (
      <Box sx={{ display: 'grid', placeItems: 'center', minHeight: '100vh', p: 3 }}>
        <Alert
          severity="error"
          action={
            <Button color="inherit" size="small" onClick={() => void session.refetch()}>
              Try again
            </Button>
          }
        >
          Could not check your session: {session.error.message}
        </Alert>
      </Box>
    )
  }

  if (!session.data) return <Navigate to="/login" replace state={{ from: location }} />

  return <Outlet />
}
