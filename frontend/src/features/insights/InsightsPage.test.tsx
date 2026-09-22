import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { HttpResponse } from 'msw'
import { beforeEach, describe, expect, it } from 'vitest'
import { mockInsights, renderApp, signedIn } from '../../test/helpers'
import { overview } from '../../test/insightsFixtures'

const failing = () => new HttpResponse(null, { status: 500 })

async function renderInsights() {
  const utils = renderApp('/insights')
  await screen.findByRole('heading', { name: 'Insights' })
  return utils
}

/** A headline number's card, found by the label it is named after. */
const card = (label: string) => screen.getByRole('group', { name: label })

/** A section of the page, found by its heading, so a name shown in two sections can be told apart. */
const section = (name: string) => screen.findByRole('region', { name })

describe('the insights dashboard', () => {
  beforeEach(() => signedIn())

  describe('the headline numbers', () => {
    it('shows headcount, payroll, and the average and median salary', async () => {
      mockInsights()

      await renderInsights()

      await waitFor(() => expect(within(card('Headcount')).getByText('9,517')).toBeInTheDocument())
      expect(within(card('Annual payroll')).getByText('$804,054,519')).toBeInTheDocument()
      expect(within(card('Average salary')).getByText('$84,486')).toBeInTheDocument()
      expect(within(card('Median salary')).getByText('$78,496')).toBeInTheDocument()
    })

    it('says what the figures cover and how current the exchange rates are', async () => {
      mockInsights()

      await renderInsights()

      expect(await screen.findByText('Active employees in 8 countries and 8 departments.')).toBeInTheDocument()
      expect(screen.getByText('Amounts are in USD, converted at exchange rates as of 1 Jan 2026.')).toBeInTheDocument()
    })

    it('reports a failure to load them without hiding the rest of the page', async () => {
      mockInsights({ overview: failing })

      await renderInsights()

      expect(await screen.findByText('Could not load the overview: Request failed (500)')).toBeInTheDocument()
      expect(await screen.findByRole('heading', { name: 'Pay by country' })).toBeInTheDocument()
    })

    it('says amounts are in USD with no conversion note, when the API gives no exchange-rate date', async () => {
      mockInsights({ overview: () => HttpResponse.json({ data: { ...overview, rates_as_of: null } }) })

      await renderInsights()

      expect(await screen.findByText('Amounts are in USD.')).toBeInTheDocument()
      expect(screen.queryByText(/converted at exchange rates/)).not.toBeInTheDocument()
    })
  })

  describe('pay by group', () => {
    it('shows the pay range for each country, the way the API computed it', async () => {
      mockInsights()

      await renderInsights()

      const link = await screen.findByRole('link', { name: 'India' })
      const row = link.closest('tr')!
      for (const text of ['2,099', '$13,442', '$25,079', '$31,760', '$41,192', '$110,042', '$34,000']) {
        expect(within(row).getByText(text)).toBeInTheDocument()
      }
    })

    it('links each group to the directory filtered to it', async () => {
      mockInsights()

      await renderInsights()

      expect(await screen.findByRole('link', { name: 'India' })).toHaveAttribute('href', '/employees?country_id=2')
      expect(screen.getByRole('link', { name: 'United States' })).toHaveAttribute('href', '/employees?country_id=1')
    })

    it('can group by department or job title instead', async () => {
      const requests = mockInsights()
      const user = userEvent.setup()

      await renderInsights()
      await screen.findByRole('link', { name: 'India' })

      await user.click(screen.getByRole('button', { name: 'Department' }))

      const department = await screen.findByRole('link', { name: 'Engineering' })
      expect(department).toHaveAttribute('href', '/employees?department_id=1')
      expect(screen.getByRole('heading', { name: 'Pay by department' })).toBeInTheDocument()
      expect(requests.some((url) => url.searchParams.get('group_by') === 'department')).toBe(true)

      await user.click(screen.getByRole('button', { name: 'Job title' }))

      expect(await screen.findByRole('link', { name: 'Staff Engineer' })).toHaveAttribute('href', '/employees?job_title_id=9')
    })

    it('reports a failure to load, and tries again on request', async () => {
      let failingNow = true
      mockInsights({ stats: () => (failingNow ? failing() : HttpResponse.json({ data: [] })) })
      const user = userEvent.setup()

      await renderInsights()

      expect(await screen.findByText('Could not load the pay statistics: Request failed (500)')).toBeInTheDocument()
      failingNow = false
      await user.click(screen.getByRole('button', { name: 'Try again' }))
      expect(await screen.findByText('No active employees to report on.')).toBeInTheDocument()
    })
  })

  describe('the salary distribution', () => {
    it('lists how many people fall in each pay band, as a table a screen reader can use', async () => {
      mockInsights()

      await renderInsights()

      const table = await screen.findByRole('table', { name: 'Salary distribution (USD)' })
      const rows = within(table).getAllByRole('row').slice(1)
      expect(within(rows[0]).getByText('$13,442 – $49,802')).toBeInTheDocument()
      expect(within(rows[0]).getByText('2,746')).toBeInTheDocument()
      expect(within(rows[1]).getByText('$49,802 – $86,161')).toBeInTheDocument()
      expect(within(rows[1]).getByText('2,411')).toBeInTheDocument()
    })

    it('reports a failure to load it, and tries again on request', async () => {
      let failingNow = true
      mockInsights({ distribution: () => (failingNow ? failing() : HttpResponse.json({ data: [] })) })
      const user = userEvent.setup()

      await renderInsights()

      expect(await screen.findByText('Could not load the salary distribution: Request failed (500)')).toBeInTheDocument()
      failingNow = false
      await user.click(screen.getByRole('button', { name: 'Try again' }))
      expect(await screen.findByText('No active employees to report on.')).toBeInTheDocument()
    })
  })

  describe('the highest and lowest paid', () => {
    it('starts with the highest paid, each linking to their page', async () => {
      mockInsights()

      await renderInsights()

      const region = within(await section('Highest and lowest paid'))
      const link = await region.findByRole('link', { name: 'Diego Miller' })
      expect(link).toHaveAttribute('href', '/employees/10')
      expect(within(link.closest('tr')!).getByText('$449,753')).toBeInTheDocument()
      expect(region.getByRole('link', { name: 'Yuki Hansen' })).toBeInTheDocument()
    })

    it('switches to the lowest paid', async () => {
      const requests = mockInsights()
      const user = userEvent.setup()

      await renderInsights()
      const region = within(await section('Highest and lowest paid'))
      await region.findByRole('link', { name: 'Diego Miller' })
      await user.click(region.getByRole('tab', { name: 'Lowest paid' }))

      expect(await region.findByRole('link', { name: 'Yuki Murphy' })).toBeInTheDocument()
      expect(region.queryByRole('link', { name: 'Diego Miller' })).not.toBeInTheDocument()
      expect(requests.some((url) => url.searchParams.get('direction') === 'asc')).toBe(true)
    })

    it('reports a failure to load, and tries again on request', async () => {
      let failingNow = true
      mockInsights({ topEarners: () => (failingNow ? failing() : HttpResponse.json({ data: [] })) })
      const user = userEvent.setup()

      await renderInsights()

      expect(await screen.findByText('Could not load the top earners: Request failed (500)')).toBeInTheDocument()
      failingNow = false
      await user.click(screen.getByRole('button', { name: 'Try again' }))
      expect(await screen.findByRole('table', { name: 'Highest paid' })).toBeInTheDocument()
    })
  })

  describe('pay outliers', () => {
    it('explains how outliers are found', async () => {
      mockInsights()

      await renderInsights()

      expect(await screen.findByText(/same job title in the same country/)).toBeInTheDocument()
    })

    it('shows who is paid outside their peers, with what their peers earn', async () => {
      mockInsights()

      await renderInsights()

      const region = within(await section('Pay outliers'))
      const row = (await region.findByRole('link', { name: 'Diego Miller' })).closest('tr')!
      for (const text of ['Engineering Manager', 'Canada', 'CA$616,100', 'Above range', '30', 'CA$255,050', 'CA$218,975 – CA$293,375']) {
        expect(within(row).getByText(text)).toBeInTheDocument()
      }
    })

    it('marks those paid below their peers as well', async () => {
      mockInsights()

      await renderInsights()

      expect(await within(await section('Pay outliers')).findByText('Below range')).toBeInTheDocument()
    })

    it('says so when nobody is an outlier', async () => {
      mockInsights({ outliers: () => HttpResponse.json({ data: [] }) })

      await renderInsights()

      expect(await screen.findByText("Nobody is paid outside their peer group's range.")).toBeInTheDocument()
    })

    it('reports a failure to load, and tries again on request', async () => {
      let failingNow = true
      mockInsights({ outliers: () => (failingNow ? failing() : HttpResponse.json({ data: [] })) })
      const user = userEvent.setup()

      await renderInsights()

      expect(await screen.findByText('Could not load the outliers: Request failed (500)')).toBeInTheDocument()
      failingNow = false
      await user.click(screen.getByRole('button', { name: 'Try again' }))
      expect(await screen.findByText("Nobody is paid outside their peer group's range.")).toBeInTheDocument()
    })
  })
})
