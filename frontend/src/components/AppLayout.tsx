import AppBar from '@mui/material/AppBar'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import CircularProgress from '@mui/material/CircularProgress'
import Container from '@mui/material/Container'
import Toolbar from '@mui/material/Toolbar'
import Typography from '@mui/material/Typography'
import { Suspense } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { useSession, useSignOut } from '../auth/session'

const links = [
  { to: '/employees', label: 'Employees' },
  { to: '/insights', label: 'Insights' },
]

/** The frame around every signed-in page: title, navigation, who is signed in, and sign out. */
export default function AppLayout() {
  const { data: user } = useSession()
  const signOut = useSignOut()

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
      <AppBar position="static" color="inherit" elevation={0} sx={{ borderBottom: 1, borderColor: 'divider' }}>
        <Toolbar sx={{ gap: 2 }}>
          <Typography variant="h6" component="span" sx={{ fontWeight: 600, mr: 2 }}>
            Salary Management
          </Typography>
          <Box component="nav" aria-label="Main" sx={{ display: 'flex', gap: 1, flexGrow: 1 }}>
            {links.map((link) => (
              <Button
                key={link.to}
                component={NavLink}
                to={link.to}
                color="inherit"
                sx={{ '&.active': { color: 'primary.main', fontWeight: 700 } }}
              >
                {link.label}
              </Button>
            ))}
          </Box>
          <Typography variant="body2" color="text.secondary">
            {user?.email}
          </Typography>
          <Button variant="outlined" size="small" onClick={() => signOut.mutate()} disabled={signOut.isPending}>
            Sign out
          </Button>
        </Toolbar>
      </AppBar>
      <Container component="main" maxWidth="xl" sx={{ py: 3 }}>
        <Suspense fallback={<CircularProgress aria-label="Loading the page" />}>
          <Outlet />
        </Suspense>
      </Container>
    </Box>
  )
}
