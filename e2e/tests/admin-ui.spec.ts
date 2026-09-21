import { expect, test, type Page } from '@playwright/test'

// The look and feel of the admin panel in a real browser: the things a stylesheet or a script can get wrong that no
// server-side test can see (which rule wins, whether the font really loads, whether a button fits its label).

const adminEmail = process.env.ADMIN_EMAIL ?? 'admin@acme.example'
const adminPassword = process.env.ADMIN_PASSWORD ?? 'admin-panel-demo'
const screenshots = process.env.SCREENSHOTS_DIR ?? 'screenshots'

const shot = (page: Page, name: string, fullPage = false) =>
  page.screenshot({ path: `${screenshots}/${name}.png`, fullPage })

async function signIn(page: Page) {
  await page.goto('/admin/login')
  await page.getByLabel('Email').fill(adminEmail)
  await page.getByLabel('Password').fill(adminPassword)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
}

test('the panel is set in Montserrat, served from this app, and asks nothing of any other site', async ({ page, baseURL }) => {
  const hosts = new Set<string>()
  const fonts: string[] = []
  page.on('request', (request) => hosts.add(new URL(request.url()).host))
  page.on('response', (response) => {
    if (response.url().endsWith('.woff2')) fonts.push(`${response.status()} ${new URL(response.url()).pathname}`)
  })

  await signIn(page)
  await page.evaluate(() => document.fonts.ready)

  expect(await page.evaluate(() => getComputedStyle(document.body).fontFamily)).toContain('Montserrat')
  expect(await page.evaluate(() => document.fonts.check('600 16px Montserrat'))).toBe(true)
  expect(fonts).toContain('200 /admin-assets/fonts/montserrat-latin-wght-normal.woff2')
  expect([...hosts]).toEqual([new URL(baseURL as string).host])
})

test('on a desktop screen the sidebar is always there, with no menu button, and Sign out fits its label', async ({ page }) => {
  await signIn(page)

  await expect(page.locator('#sidebar')).toBeVisible()
  await expect(page.locator('[data-sidebar-toggle]')).toBeHidden()
  await expect(page.locator('#sidebar a[aria-current="page"]')).toHaveText('Dashboard')

  const signOut = page.getByRole('button', { name: 'Sign out' })
  await expect(signOut).toBeVisible()
  const box = await signOut.boundingBox()
  expect(box?.width ?? 0).toBeGreaterThan(150) // as wide as the account card, not squeezed into a square
  expect(box?.height ?? 0).toBeLessThan(50)
  await expect(signOut).toHaveText('Sign out')
})

test('the theme can be switched, is remembered across pages and reloads, and follows the system until then', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' })
  await signIn(page)
  const toggle = page.locator('header.topbar [data-theme-toggle]')

  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
  await expect(toggle).toHaveAttribute('aria-pressed', 'false')

  await toggle.click()
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await expect(toggle).toHaveAttribute('aria-pressed', 'true')
  await expect(toggle).toHaveAttribute('aria-label', 'Use the light theme')
  expect(await page.evaluate(() => localStorage.getItem('admin-theme'))).toBe('dark')
  await expect(page.locator('body')).toHaveCSS('background-color', 'rgb(11, 16, 36)')
  await shot(page, 'admin-dark-dashboard', true)

  await page.goto('/admin/tables/employees') // another page: still dark, and no flash of the light one
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await page.reload()
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')

  await page.locator('header.topbar [data-theme-toggle]').click()
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
  expect(await page.evaluate(() => localStorage.getItem('admin-theme'))).toBe('light')
})

test('with nothing saved the theme is the system one', async ({ browser, baseURL }) => {
  const context = await browser.newContext({ colorScheme: 'dark', baseURL })
  const page = await context.newPage()
  await page.goto('/admin/login')

  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await shot(page, 'admin-dark-sign-in')
  await context.close()
})

test('on a phone the sidebar is a drawer that opens from the menu button and closes again', async ({ browser, baseURL }) => {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, baseURL })
  const page = await context.newPage()
  await signIn(page)

  const sidebar = page.locator('#sidebar')
  const menu = page.locator('[data-sidebar-toggle]')
  const offscreen = async () => ((await sidebar.boundingBox())?.x ?? 0) < 0

  await expect(menu).toBeVisible()
  await expect(menu).toHaveAttribute('aria-expanded', 'false')
  expect(await offscreen()).toBe(true)
  await shot(page, 'admin-mobile-dashboard')

  await menu.click()
  await expect(menu).toHaveAttribute('aria-expanded', 'true')
  await expect(page.locator('body')).toHaveClass(/sidebar-open/)
  await expect.poll(offscreen).toBe(false)
  await shot(page, 'admin-mobile-menu')

  await page.keyboard.press('Escape') // Escape closes it
  await expect(page.locator('body')).not.toHaveClass(/sidebar-open/)
  await expect.poll(offscreen).toBe(true)

  await menu.click()
  await page.locator('[data-sidebar-backdrop]').click({ position: { x: 370, y: 400 } }) // and so does the backdrop
  await expect(page.locator('body')).not.toHaveClass(/sidebar-open/)

  await menu.click()
  await page.getByRole('link', { name: 'API monitor' }).click() // and choosing a page
  await expect(page.getByRole('heading', { name: 'API monitor' })).toBeVisible()
  await expect(page.locator('body')).not.toHaveClass(/sidebar-open/)

  await context.close()
})
