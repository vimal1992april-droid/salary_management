import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { delay, http, HttpResponse } from 'msw'
import { beforeEach, describe, expect, it } from 'vitest'
import { lookups, makeEmployee, pageOf } from '../../test/fixtures'
import { mockDirectory, renderApp, signedIn } from '../../test/helpers'
import { server } from '../../test/server'

const india = { id: 2, name: 'India', iso_code: 'IN' }

/** A few employees on a page of a much bigger directory, so pagination has somewhere to go. */
function bigDirectory(params: URLSearchParams) {
  return pageOf([makeEmployee(), makeEmployee(), makeEmployee()], {
    page: Number(params.get('page') ?? 1),
    per_page: Number(params.get('per_page') ?? 25),
    total: 10_000,
    total_pages: 400,
  })
}

const location = () => screen.getByTestId('location').textContent

describe('the employee directory', () => {
  beforeEach(() => signedIn())

  describe('what it shows', () => {
    it('lists each employee with their details', async () => {
      mockDirectory(() =>
        pageOf([makeEmployee({ id: 7, first_name: 'Asha', last_name: 'Verma', full_name: 'Asha Verma' })]),
      )

      renderApp('/employees')

      const link = await screen.findByRole('link', { name: 'Asha Verma' })
      const row = link.closest('tr')!
      expect(link).toHaveAttribute('href', '/employees/7')
      for (const text of ['E00007', 'asha.verma@acme.example', 'United States', 'Engineering', 'Software Engineer II', '1 Mar 2022', '$90,000', 'Active']) {
        expect(within(row).getByText(text)).toBeInTheDocument()
      }
    })

    it('shows a salary in its own currency with the USD equivalent beside it', async () => {
      mockDirectory(() =>
        pageOf([makeEmployee({ country: india, salary: { amount: '5104900.0', currency: 'INR', usd: '61258.8' } })]),
      )

      renderApp('/employees')

      expect(await screen.findByText('₹5,104,900')).toBeInTheDocument()
      expect(screen.getByText('≈ $61,259')).toBeInTheDocument()
    })

    it('marks inactive employees', async () => {
      mockDirectory(() => pageOf([makeEmployee({ status: 'inactive' })]))

      renderApp('/employees')

      expect(await screen.findByText('Inactive')).toBeInTheDocument()
    })

    it('shows a progress bar while the employees load', async () => {
      server.use(
        http.get('*/api/lookups', () => HttpResponse.json(lookups)),
        http.get('*/api/employees', async () => {
          await delay(150)
          return HttpResponse.json(pageOf([makeEmployee()]))
        }),
      )

      renderApp('/employees')

      await screen.findByRole('heading', { name: 'Employees' })
      expect(screen.getByRole('progressbar')).toBeInTheDocument()
      expect(await screen.findByRole('link', { name: 'Asha Verma' })).toBeInTheDocument()
    })

    it('says so when nothing matches, and the filter bar offers to clear the filters', async () => {
      const requests = mockDirectory(() => pageOf([]))
      const user = userEvent.setup()

      renderApp('/employees?country_id=2')

      expect(await screen.findByText('No employees match these filters.')).toBeInTheDocument()
      await user.click(screen.getByRole('button', { name: 'Clear filters' }))

      await waitFor(() => expect(requests.at(-1)?.get('country_id')).toBeNull())
      expect(location()).toBe('/employees')
    })

    it('does not offer to clear filters when there are none', async () => {
      mockDirectory(() => pageOf([]))

      renderApp('/employees')

      expect(await screen.findByText('No employees match these filters.')).toBeInTheDocument()
      expect(screen.queryByRole('button', { name: 'Clear filters' })).not.toBeInTheDocument()
    })

    it('reports a failure to load, and loads again on request', async () => {
      let failing = true
      mockDirectory(() => (failing ? new HttpResponse(null, { status: 500 }) : pageOf([makeEmployee()])))
      const user = userEvent.setup()

      renderApp('/employees')

      expect(await screen.findByRole('alert')).toHaveTextContent('Could not load employees: Request failed (500)')
      failing = false
      await user.click(screen.getByRole('button', { name: 'Try again' }))
      expect(await screen.findByRole('link', { name: 'Asha Verma' })).toBeInTheDocument()
    })
  })

  describe('paging', () => {
    it('shows where the page sits in the whole directory', async () => {
      mockDirectory(bigDirectory)

      renderApp('/employees')

      expect(await screen.findByText('1–25 of 10,000')).toBeInTheDocument()
    })

    it('moves to the next and previous page, and keeps the page in the URL', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees')
      await user.click(await screen.findByRole('button', { name: 'Go to next page' }))

      expect(await screen.findByText('26–50 of 10,000')).toBeInTheDocument()
      expect(requests.at(-1)?.get('page')).toBe('2')
      expect(location()).toBe('/employees?page=2')

      await user.click(screen.getByRole('button', { name: 'Go to previous page' }))

      expect(await screen.findByText('1–25 of 10,000')).toBeInTheDocument()
      expect(location()).toBe('/employees')
    })

    it('changes the page size and returns to the first page', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees?page=3')
      await user.selectOptions(await screen.findByLabelText('Rows per page'), '50')

      await waitFor(() => expect(requests.at(-1)?.get('per_page')).toBe('50'))
      expect(requests.at(-1)?.get('page')).toBe('1')
      expect(location()).toBe('/employees?per_page=50')
    })
  })

  describe('sorting', () => {
    it('starts sorted by name, and says which column is sorted', async () => {
      mockDirectory(bigDirectory)

      renderApp('/employees')

      expect(await screen.findByRole('columnheader', { name: /Name/ })).toHaveAttribute('aria-sort', 'ascending')
      expect(screen.getByRole('columnheader', { name: /Salary/ })).not.toHaveAttribute('aria-sort', 'ascending')
    })

    it('sorts by a column, then reverses on the second click', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees')
      await user.click(await screen.findByRole('button', { name: /Salary/ }))

      await waitFor(() => expect([requests.at(-1)?.get('sort'), requests.at(-1)?.get('direction')]).toEqual(['salary', 'asc']))
      expect(screen.getByRole('columnheader', { name: /Salary/ })).toHaveAttribute('aria-sort', 'ascending')

      await user.click(screen.getByRole('button', { name: /Salary/ }))

      await waitFor(() => expect(requests.at(-1)?.get('direction')).toBe('desc'))
      expect(screen.getByRole('columnheader', { name: /Salary/ })).toHaveAttribute('aria-sort', 'descending')
      expect(location()).toBe('/employees?sort=salary&direction=desc')
    })

    it('goes back to the first page when the order changes', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees?page=4')
      await user.click(await screen.findByRole('button', { name: /Hired/ }))

      await waitFor(() => expect(requests.at(-1)?.get('sort')).toBe('hire_date'))
      expect(requests.at(-1)?.get('page')).toBe('1')
    })

    it('can sort by every column that has a meaning to sort by', async () => {
      mockDirectory(bigDirectory)

      renderApp('/employees')
      await screen.findByRole('columnheader', { name: /Name/ })

      for (const name of ['Number', 'Name', 'Country', 'Department', 'Job title', 'Hired', 'Salary']) {
        expect(screen.getByRole('button', { name: new RegExp(name) })).toBeInTheDocument()
      }
      expect(screen.queryByRole('button', { name: /Email/ })).not.toBeInTheDocument()
    })
  })

  describe('filtering and searching', () => {
    it('shows active employees unless told otherwise', async () => {
      const requests = mockDirectory(bigDirectory)

      renderApp('/employees')

      expect(await screen.findByLabelText('Status')).toHaveValue('active')
      expect(requests[0].get('status')).toBe('active')
    })

    it('filters by country, department and job title, each returning to the first page', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees?page=3')
      await screen.findByRole('option', { name: 'India' })

      await user.selectOptions(screen.getByLabelText('Country'), 'India')
      await waitFor(() => expect(requests.at(-1)?.get('country_id')).toBe('2'))
      expect(requests.at(-1)?.get('page')).toBe('1')

      await user.selectOptions(screen.getByLabelText('Department'), 'Sales')
      await waitFor(() => expect(requests.at(-1)?.get('department_id')).toBe('2'))

      await user.selectOptions(screen.getByLabelText('Job title'), 'Account Executive')
      await waitFor(() => expect(requests.at(-1)?.get('job_title_id')).toBe('2'))

      expect(location()).toBe('/employees?country_id=2&department_id=2&job_title_id=2')
    })

    it('can show inactive employees, or everyone', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees')
      await user.selectOptions(await screen.findByLabelText('Status'), 'Inactive')
      await waitFor(() => expect(requests.at(-1)?.get('status')).toBe('inactive'))

      await user.selectOptions(screen.getByLabelText('Status'), 'All statuses')
      await waitFor(() => expect(requests.at(-1)?.has('status')).toBe(false))
      expect(location()).toBe('/employees?status=all')
    })

    it('searches as the user types, once they pause, from the first page', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees?page=3')
      await user.type(await screen.findByRole('searchbox', { name: 'Search' }), 'priya')

      await waitFor(() => expect(requests.at(-1)?.get('q')).toBe('priya'))
      expect(requests.at(-1)?.get('page')).toBe('1')
      expect(requests.map((request) => request.get('q'))).not.toContain('pri')
    })

    it('restores everything from the URL, so a link or a refresh shows the same view', async () => {
      const requests = mockDirectory(bigDirectory)

      renderApp('/employees?q=priya&country_id=2&status=all&sort=hire_date&direction=desc&page=3&per_page=50')

      await screen.findByRole('option', { name: 'India' }) // a select can only show its value once its options exist
      expect(screen.getByLabelText('Country')).toHaveValue('2')
      expect(screen.getByRole('searchbox', { name: 'Search' })).toHaveValue('priya')
      expect(screen.getByLabelText('Status')).toHaveValue('all')
      expect(Object.fromEntries(requests[0])).toEqual({
        q: 'priya', country_id: '2', sort: 'hire_date', direction: 'desc', page: '3', per_page: '50',
      })
    })

    it('clears the search and every filter in one click', async () => {
      const requests = mockDirectory(bigDirectory)
      const user = userEvent.setup()

      renderApp('/employees?q=priya&country_id=2&department_id=2')
      await user.click(await screen.findByRole('button', { name: 'Clear filters' }))

      await waitFor(() => expect(requests.at(-1)?.get('country_id')).toBeNull())
      expect(requests.at(-1)?.get('q')).toBeNull()
      expect(requests.at(-1)?.get('department_id')).toBeNull()
      expect(screen.getByRole('searchbox', { name: 'Search' })).toHaveValue('')
    })
  })

  describe('exporting', () => {
    it('links to a CSV of the current filters, without the page', async () => {
      mockDirectory(bigDirectory)

      renderApp('/employees?country_id=2&page=3&per_page=50')

      expect(await screen.findByRole('link', { name: 'Export CSV' })).toHaveAttribute(
        'href',
        '/api/employees/export?country_id=2&status=active&sort=name&direction=asc',
      )
    })
  })
})
