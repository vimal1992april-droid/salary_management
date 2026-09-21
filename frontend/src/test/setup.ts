import '@testing-library/jest-dom/vitest'
import { cleanup, configure } from '@testing-library/react'
import { afterAll, afterEach, beforeAll } from 'vitest'
import { server } from './server'

// jsdom has no ResizeObserver, which the charts use to fit their container.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
}

// The first MUI render in a test file is slow (about 1.5 s on a cold start), and CI machines are slower still.
configure({ asyncUtilTimeout: 4000 })

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))

afterEach(() => {
  cleanup()
  server.resetHandlers()
})

afterAll(() => server.close())
