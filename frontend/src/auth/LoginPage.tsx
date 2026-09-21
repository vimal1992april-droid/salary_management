import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Paper from '@mui/material/Paper'
import TextField from '@mui/material/TextField'
import Typography from '@mui/material/Typography'
import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, type Location } from 'react-router-dom'
import { ApiError } from '../api/client'
import { useSession, useSignIn } from './session'

type FieldErrors = { email?: string; password?: string }

function messageFor(error: Error) {
  if (error instanceof ApiError && error.status === 429) {
    return 'Too many attempts. Please wait a few minutes and try again.'
  }
  return error.message
}

export default function LoginPage() {
  const session = useSession()
  const signIn = useSignIn()
  const location = useLocation()
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({})

  // Return to the page the visitor first asked for, if the auth gate sent them here.
  const from = (location.state as { from?: Location } | null)?.from
  if (session.data) return <Navigate to={from ? `${from.pathname}${from.search}` : '/employees'} replace />

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const email = String(form.get('email') ?? '').trim()
    const password = String(form.get('password') ?? '')

    const errors: FieldErrors = {}
    if (!email) errors.email = 'Enter your email'
    if (!password) errors.password = 'Enter your password'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    signIn.mutate({ email, password })
  }

  return (
    <Box sx={{ display: 'grid', placeItems: 'center', minHeight: '100vh', p: 2 }}>
      <Paper component="form" noValidate onSubmit={handleSubmit} sx={{ p: 4, width: '100%', maxWidth: 400 }}>
        <Typography variant="overline" color="text.secondary">
          Salary Management
        </Typography>
        <Typography variant="h4" component="h1" gutterBottom>
          Sign in
        </Typography>

        {signIn.error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {messageFor(signIn.error)}
          </Alert>
        )}

        <TextField
          name="email"
          label="Email"
          type="email"
          autoComplete="username"
          autoFocus
          fullWidth
          margin="normal"
          error={Boolean(fieldErrors.email)}
          helperText={fieldErrors.email}
        />
        <TextField
          name="password"
          label="Password"
          type="password"
          autoComplete="current-password"
          fullWidth
          margin="normal"
          error={Boolean(fieldErrors.password)}
          helperText={fieldErrors.password}
        />
        <Button type="submit" variant="contained" size="large" fullWidth disabled={signIn.isPending} sx={{ mt: 2 }}>
          Sign in
        </Button>
      </Paper>
    </Box>
  )
}
