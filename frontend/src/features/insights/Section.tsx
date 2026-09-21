import Alert from '@mui/material/Alert'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import CircularProgress from '@mui/material/CircularProgress'
import Paper from '@mui/material/Paper'
import Typography from '@mui/material/Typography'
import { useId, type ReactNode } from 'react'

/** A named region of the dashboard, so assistive technology (and tests) can find it by its heading. */
export function Section({ title, actions, children }: { title: string; actions?: ReactNode; children: ReactNode }) {
  const headingId = useId()
  return (
    <Paper component="section" aria-labelledby={headingId} variant="outlined" sx={{ p: 3 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <Typography id={headingId} variant="h6" component="h2">
          {title}
        </Typography>
        {actions}
      </Box>
      {children}
    </Paper>
  )
}

export function Loading() {
  return (
    <Box sx={{ display: 'grid', placeItems: 'center', py: 4 }}>
      <CircularProgress size={28} />
    </Box>
  )
}

/** A section's own failure: it says what could not be loaded and offers to try again. */
export function SectionError({ what, error, onRetry }: { what: string; error: Error; onRetry: () => void }) {
  return (
    <Alert
      severity="error"
      action={
        <Button color="inherit" size="small" onClick={onRetry}>
          Try again
        </Button>
      }
    >
      Could not load {what}: {error.message}
    </Alert>
  )
}
