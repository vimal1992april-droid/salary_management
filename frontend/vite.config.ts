import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Forward API calls to the Rails server so the browser sees a single origin (no CORS in dev).
    proxy: {
      '/api': 'http://localhost:3000',
    },
  },
})
