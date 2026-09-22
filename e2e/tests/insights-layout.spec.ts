import { expect, test, type Page } from '@playwright/test'

// The Insights dashboard's spacing: real layout, which jsdom (the frontend's own unit tests) cannot see. Each
// section is its own bordered card with a consistent gap between cards; within a card, related lines of text sit
// close together. The headline numbers are meant to follow that same rule.

const email = process.env.HR_EMAIL ?? 'hr@acme.example'
const password = process.env.HR_PASSWORD ?? 'salary-manager-demo'

async function signIn(page: Page) {
  await page.goto('/employees')
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password').fill(password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Employees' })).toBeVisible()
}

async function top(page: Page, locator: ReturnType<Page['locator']>) {
  const box = await locator.boundingBox()
  if (!box) throw new Error('element has no box')
  return box.y
}
async function bottom(page: Page, locator: ReturnType<Page['locator']>) {
  const box = await locator.boundingBox()
  if (!box) throw new Error('element has no box')
  return box.y + box.height
}

test('the headline numbers and their two-line note sit in one card, not spread across three', async ({ page }) => {
  await signIn(page)
  await page.getByRole('link', { name: 'Insights' }).click()
  await expect(page.getByRole('heading', { name: 'Insights' })).toBeVisible()

  const headcount = page.getByRole('group', { name: 'Headcount' })
  const scope = page.getByText(/Active employees in \d+ countries/)
  const rates = page.getByText(/Amounts are in USD/)
  const nextSection = page.getByRole('heading', { name: 'Pay by country' })
  await expect(headcount).toBeVisible()
  await expect(scope).toBeVisible()
  await expect(rates).toBeVisible()

  const cardsBottom = await bottom(page, headcount)
  const scopeTop = await top(page, scope)
  const scopeBottom = await bottom(page, scope)
  const ratesTop = await top(page, rates)
  const sectionTop = await top(page, nextSection)

  const betweenTheTwoNoteLines = ratesTop - scopeBottom
  const betweenCardsAndNote = scopeTop - cardsBottom
  const betweenNoteAndNextSection = sectionTop - ratesTop

  // The two lines of one note belong together: a line's own height apart at most, not a whole section's worth of gap.
  expect(betweenTheTwoNoteLines).toBeLessThan(12)
  // The note is the headline numbers' caption, closer to them than a full gap between unrelated sections.
  expect(betweenCardsAndNote).toBeLessThan(betweenNoteAndNextSection)
})
