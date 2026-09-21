import { expect, test, type Page } from '@playwright/test'

const email = process.env.HR_EMAIL ?? 'hr@acme.example'
const password = process.env.HR_PASSWORD ?? 'salary-manager-demo'
const screenshots = process.env.SCREENSHOTS_DIR ?? 'screenshots'

const shot = (page: Page, name: string, fullPage = false) =>
  page.screenshot({ path: `${screenshots}/${name}.png`, fullPage })

test('an HR manager can sign in, add someone, change their salary and read how the organisation pays its people', async ({ page }) => {
  // --- Signed out, the app asks for a login ---------------------------------------------------------------------
  await page.goto('/employees')
  await expect(page).toHaveURL(/\/login/)
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible()
  await shot(page, '01-sign-in')

  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password').fill('not-the-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('alert')).toContainText('Invalid email or password')

  await page.getByLabel('Password').fill(password)
  await page.getByRole('button', { name: 'Sign in' }).click()

  // --- The directory, with 10,000 employees behind it ------------------------------------------------------------
  await expect(page.getByRole('heading', { name: 'Employees' })).toBeVisible()
  await expect(page).toHaveURL(/\/employees$/) // back where they were going
  await expect(page.getByText(/of 9,\d{3}$/)).toBeVisible() // active employees
  await shot(page, '02-directory')

  await page.getByRole('searchbox', { name: 'Search' }).fill('E00500')
  await expect(page.getByRole('link', { name: 'Diego Miller' })).toBeVisible()
  await expect(page).toHaveURL(/q=E00500/)
  await expect(page.getByRole('row')).toHaveCount(2) // header and the one match

  await page.getByRole('link', { name: 'Diego Miller' }).click()
  await expect(page.getByRole('heading', { name: 'Diego Miller' })).toBeVisible()
  await expect(page.getByText('CA$616,100').first()).toBeVisible() // paid in Canadian dollars
  await shot(page, '03-employee')

  // --- Add an employee (a new one every run, so the test can be repeated) ----------------------------------------
  const number = `E2E${Date.now().toString().slice(-7)}`
  await page.getByRole('link', { name: 'Employees', exact: true }).click()
  await page.getByRole('link', { name: 'Add employee' }).click()
  await expect(page.getByRole('heading', { name: 'Add employee' })).toBeVisible()

  await page.getByLabel('Employee number').fill(number)
  await page.getByLabel('First name').fill('Browser')
  await page.getByLabel('Email').fill(`${number.toLowerCase()}@acme.example`)
  await page.getByLabel('Country').selectOption({ label: 'India' })
  await expect(page.getByText('Paid in INR')).toBeVisible()
  await page.getByLabel('Department').selectOption({ label: 'Engineering' })
  await page.getByLabel('Job title').selectOption({ label: 'Software Engineer II' })
  await page.getByLabel('Hire date').fill('2025-06-01')
  await page.getByLabel('Starting salary').fill('2,400,000')
  await shot(page, '04-add-employee')

  // A required field is missing: it is caught before anything is sent, and the message goes as soon as it is fixed.
  await page.getByRole('button', { name: 'Add employee' }).click()
  await expect(page.getByText('Enter a last name')).toBeVisible()
  await page.getByLabel('Last name').fill('Tester')
  await expect(page.getByText('Enter a last name')).toBeHidden()
  await page.getByRole('button', { name: 'Add employee' }).click()

  await expect(page.getByRole('heading', { name: 'Browser Tester' })).toBeVisible()
  await expect(page.getByText('Employee added')).toBeVisible()
  await expect(page.getByText('₹2,400,000').first()).toBeVisible()
  await expect(page.getByText('No salary changes have been recorded yet.')).toBeVisible()

  // --- Change their salary: it is checked, recorded with a reason, and shows in the history -----------------------
  await page.getByRole('button', { name: 'Change salary' }).click()
  const dialog = page.getByRole('dialog', { name: 'Change salary' })
  await dialog.getByRole('button', { name: 'Save change' }).click()
  await expect(dialog.getByText('Enter the new salary')).toBeVisible()
  await expect(dialog.getByText('Give a reason for the change')).toBeVisible()

  await dialog.getByLabel('New salary').fill('2,700,000')
  await dialog.getByLabel('Reason').fill('Promoted after the annual review')
  await shot(page, '05-change-salary')
  await dialog.getByRole('button', { name: 'Save change' }).click()

  await expect(page.getByText('Salary updated')).toBeVisible()
  await expect(page.getByText('₹2,700,000').first()).toBeVisible()
  const history = page.getByRole('table', { name: 'Salary history' })
  await expect(history).toContainText('₹2,400,000')
  await expect(history).toContainText('+12.5%')
  await expect(history).toContainText('Promoted after the annual review')
  await expect(history).toContainText(email)
  await shot(page, '06-salary-history')

  // --- Deactivate them: they stop counting in pay statistics, and can be brought back ---------------------------
  await page.getByRole('button', { name: 'Deactivate' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Deactivate' }).click()
  await expect(page.getByText('Employee deactivated')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Reactivate' })).toBeVisible()

  // --- The dashboard answers how the organisation pays its people ------------------------------------------------
  await page.getByRole('link', { name: 'Insights' }).click()
  await expect(page.getByRole('heading', { name: 'Insights' })).toBeVisible()
  await expect(page.getByRole('group', { name: 'Headcount' })).toContainText(/9,\d{3}/)
  await expect(page.getByRole('group', { name: 'Annual payroll' })).toContainText('$')
  await expect(page.getByRole('link', { name: 'India' })).toBeVisible() // pay by country
  await expect(page.locator('.recharts-surface').first()).toBeVisible() // the chart drew
  await expect(page.getByRole('region', { name: 'Pay outliers' }).getByRole('row').nth(1)).toBeVisible()
  await page.getByRole('button', { name: 'Job title' }).click()
  await expect(page.getByRole('heading', { name: 'Pay by job title' })).toBeVisible()
  await page.getByRole('button', { name: 'Country' }).click()
  await shot(page, '07-insights', true)

  // a group links to the directory filtered to it
  await page.getByRole('link', { name: 'India' }).click()
  await expect(page).toHaveURL(/country_id=\d+/)
  await expect(page.getByLabel('Country')).not.toHaveValue('')

  // --- Signing out ends the session -------------------------------------------------------------------------------
  await page.getByRole('button', { name: 'Sign out' }).click()
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible()
  await page.goto('/insights')
  await expect(page).toHaveURL(/\/login/)
})

test('the API is closed to anyone who has not signed in, and refuses unknown paths', async ({ request }) => {
  expect((await request.get('/api/employees')).status()).toBe(401)
  expect((await request.get('/api/insights/overview')).status()).toBe(401)
  expect((await request.get('/api/health')).ok()).toBe(true) // the one open endpoint
  expect((await request.get('/api/nope')).status()).toBe(404)
})
