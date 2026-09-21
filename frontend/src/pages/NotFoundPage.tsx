import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import { Link } from 'react-router-dom'

export default function NotFoundPage() {
  return (
    <>
      <Typography variant="h4" component="h1" gutterBottom>
        Page not found
      </Typography>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        There is nothing at this address.
      </Typography>
      <Button component={Link} to="/employees" variant="outlined">
        Go to the employees
      </Button>
    </>
  )
}
