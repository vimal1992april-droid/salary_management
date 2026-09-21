import CssBaseline from '@mui/material/CssBaseline'
import { ThemeProvider } from '@mui/material/styles'
import { QueryClientProvider, type QueryClient } from '@tanstack/react-query'
import { useState, type ReactNode } from 'react'
import { createQueryClient } from './queryClient'
import { theme } from './theme'

/** Theme and data fetching for the whole app. Tests pass their own query client. */
export function Providers({ children, queryClient }: { children: ReactNode; queryClient?: QueryClient }) {
  const [defaultClient] = useState(createQueryClient)

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <QueryClientProvider client={queryClient ?? defaultClient}>{children}</QueryClientProvider>
    </ThemeProvider>
  )
}
