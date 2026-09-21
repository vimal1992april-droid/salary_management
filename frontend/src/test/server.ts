import { setupServer } from 'msw/node'

// Tests register the handlers they need with `server.use(...)`, so every request
// a test makes is stated in the test itself. Unhandled requests fail the test.
export const server = setupServer()
