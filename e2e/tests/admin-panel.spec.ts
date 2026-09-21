import { expect, test, type Page } from '@playwright/test'

const hrEmail = process.env.HR_EMAIL ?? 'hr@acme.example'
const hrPassword = process.env.HR_PASSWORD ?? 'salary-manager-demo'
const adminEmail = process.env.ADMIN_EMAIL ?? 'admin@acme.example'
const adminPassword = process.env.ADMIN_PASSWORD ?? 'admin-panel-demo'
const screenshots = process.env.SCREENSHOTS_DIR ?? 'screenshots'

const shot = (page: Page, name: string, fullPage = true) =>
  page.screenshot({ path: `${screenshots}/${name}.png`, fullPage })

test('an administrator signs in, browses the data and the graphs, and reads every API call with its payload', async ({
  page,
  playwright,
  baseURL,
}) => {
  // --- Some traffic for the monitor to record: what the HR app would send, plus a refused and a missing call ------
  const api = await playwright.request.newContext({ baseURL })
  expect((await api.post('/api/session', { data: { email: hrEmail, password: hrPassword } })).status()).toBe(201)
  expect((await api.get('/api/employees?q=E00500')).status()).toBe(200)
  expect((await api.get('/api/insights/overview')).status()).toBe(200)
  expect((await api.post('/api/session', { data: { email: hrEmail, password: 'a-wrong-password-9' } })).status()).toBe(401)
  expect((await api.get('/api/nope')).status()).toBe(404)
  await api.dispose()

  // --- Signed out, /admin asks for the administrator's login, and the HR login does not open it ------------------
  await page.goto('/admin')
  await expect(page).toHaveURL(/\/admin\/login$/)
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible()
  await expect(page.locator('.auth-brand')).toContainText('Salary admin')
  await shot(page, 'admin-01-sign-in', false)

  await page.getByLabel('Email').fill(hrEmail)
  await page.getByLabel('Password').fill(hrPassword)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('alert')).toContainText('Invalid email or password')

  await page.getByLabel('Email').fill(adminEmail)
  await page.getByLabel('Password').fill(adminPassword)
  await page.getByRole('button', { name: 'Sign in' }).click()

  // --- The dashboard: numbers, then graphs --------------------------------------------------------------------------
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  await expect(page.locator('.kpi', { hasText: 'Employees' }).first()).toContainText('10,000')
  await expect(page.locator('figure.chart')).toHaveCount(6)
  await expect(page.locator('figure.chart svg')).toHaveCount(6) // every graph has data
  await expect(page.getByText('Headcount by department')).toBeVisible()
  await shot(page, 'admin-02-dashboard')

  // --- All the data, table by table -------------------------------------------------------------------------------------
  await page.getByRole('link', { name: 'All tables' }).click()
  await expect(page.getByRole('heading', { name: 'Data' })).toBeVisible()
  await expect(page.locator('table.tables tbody tr')).toHaveCount(8)
  await expect(page.locator('tr', { hasText: 'Employees' }).locator('td.count')).toHaveText('10,000')
  await shot(page, 'admin-03-data')

  await page.getByRole('main').getByRole('link', { name: 'Employees', exact: true }).click()
  await page.getByRole('searchbox', { name: 'Search' }).fill('E00500')
  await page.getByRole('button', { name: 'Search' }).click()
  await expect(page.locator('tbody tr')).toHaveCount(1)
  await expect(page.getByRole('cell', { name: 'Diego', exact: true })).toBeVisible()
  await shot(page, 'admin-04-table')

  await page.locator('tbody td a').first().click() // the id opens the record
  await expect(page.getByRole('term').filter({ hasText: /^salary_amount$/ })).toBeVisible()
  await expect(page.getByText('Points at this record')).toBeVisible()
  await shot(page, 'admin-05-record')

  await page.goto('/admin/tables/users')
  await expect(page.getByRole('cell', { name: adminEmail })).toBeVisible()
  await expect(page.getByText('password_digest')).toHaveCount(0) // a password digest is never shown

  // --- Which APIs are running, and how ---------------------------------------------------------------------------------
  await page.getByRole('navigation').getByRole('link', { name: 'API monitor' }).click()
  await expect(page.getByRole('heading', { name: 'API monitor' })).toBeVisible()
  await expect(page.locator('.live-database')).toContainText('up')
  await expect(page.locator('.live-recording')).toContainText('on')
  await expect(page.locator('table.endpoints tbody tr')).toHaveCount(17)
  const employeesRow = page.locator('table.endpoints tr', { has: page.getByRole('link', { name: '/api/employees', exact: true }) }).first()
  await expect(employeesRow.locator('.pill')).toHaveText('healthy')
  await expect(page.locator('.unmatched')).toContainText('matched no endpoint')
  await shot(page, 'admin-06-api-monitor')

  // --- Every call, with its payload and response ------------------------------------------------------------------------
  await page.goto('/admin/api/requests?http_method=POST&route=/api/session')
  await expect(page.locator('tbody tr').first()).toBeVisible()
  await page.locator('tbody tr', { hasText: '401' }).first().getByRole('link').click()
  await expect(page.getByRole('heading', { name: 'POST /api/session' })).toBeVisible()
  await expect(page.locator('section.request pre.payload')).toContainText('[FILTERED]')
  await expect(page.locator('section.request pre.payload')).not.toContainText('a-wrong-password-9')
  await expect(page.locator('section.response pre.payload')).toContainText('invalid_credentials')
  await shot(page, 'admin-07-call-detail')

  await page.goto('/admin/api/requests?status=4xx')
  await expect(page.locator('tbody td.path', { hasText: '/api/nope' }).first()).toBeVisible()
  await shot(page, 'admin-08-call-log')

  // --- Signing out ends the session --------------------------------------------------------------------------------------------
  await page.getByRole('button', { name: 'Sign out' }).click()
  await expect(page).toHaveURL(/\/admin\/login$/)
  await page.goto('/admin/tables/users')
  await expect(page).toHaveURL(/\/admin\/login$/)
})
