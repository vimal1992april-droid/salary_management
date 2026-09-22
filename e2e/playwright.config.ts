import { defineConfig } from '@playwright/test'

// Runs against a running instance of the whole product (see README.md in this folder). All the spec files share
// that one instance and its one database, so a test in one file that changes shared state (the HR test adds an
// employee) can race a test in another that counts rows (the admin test expects exactly 10,000). One worker makes
// the files run one after another instead of interleaved, which costs a little time and buys a suite that does not
// flake depending on how the scheduler happens to interleave them.
export default defineConfig({
  testDir: './tests',
  timeout: 90_000,
  expect: { timeout: 10_000 },
  retries: 0,
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    viewport: { width: 1440, height: 900 },
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
})
