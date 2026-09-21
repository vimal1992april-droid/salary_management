import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { delay, http, HttpResponse } from 'msw'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Employee } from '../../api/employees'
import type { SalaryChange } from '../../api/salaryChanges'
import { makeEmployee, makeSalaryChange, pageOf } from '../../test/fixtures'
import { mockDirectory, renderApp, signedIn } from '../../test/helpers'
import { server } from '../../test/server'

const asha = () =>
  makeEmployee({ id: 7, first_name: 'Asha', last_name: 'Verma', full_name: 'Asha Verma', employee_number: 'E00007' })

/** Serves one employee and their salary history. */
function mockEmployee(employee: Employee = asha(), history: SalaryChange[] = []) {
  server.use(
    http.get(`*/api/employees/${employee.id}`, () => HttpResponse.json({ data: employee })),
    http.get(`*/api/employees/${employee.id}/salary_changes`, () => HttpResponse.json({ data: history })),
  )
}

describe('the employee page', () => {
  beforeEach(() => signedIn())

  describe('the profile', () => {
    it("shows the employee's details", async () => {
      mockEmployee()

      renderApp('/employees/7')

      expect(await screen.findByRole('heading', { name: 'Asha Verma' })).toBeInTheDocument()
      for (const text of ['E00007', 'asha.verma@acme.example', 'United States', 'Engineering', 'Software Engineer II', '1 Mar 2022', 'Active']) {
        expect(screen.getByText(text)).toBeInTheDocument()
      }
    })

    it('shows the current salary, with the USD equivalent when it is in another currency', async () => {
      mockEmployee(makeEmployee({ ...asha(), salary: { amount: '5104900.0', currency: 'INR', usd: '61258.8' } }))

      renderApp('/employees/7')

      expect(await screen.findByText('₹5,104,900')).toBeInTheDocument()
      expect(screen.getByText('≈ $61,259 at the current rate')).toBeInTheDocument()
    })

    it('marks an inactive employee', async () => {
      mockEmployee(makeEmployee({ ...asha(), status: 'inactive' }))

      renderApp('/employees/7')

      expect(await screen.findByText('Inactive')).toBeInTheDocument()
    })

    it('shows a progress bar while loading', async () => {
      server.use(
        http.get('*/api/employees/7', async () => {
          await delay(150)
          return HttpResponse.json({ data: asha() })
        }),
        http.get('*/api/employees/7/salary_changes', () => HttpResponse.json({ data: [] })),
      )

      renderApp('/employees/7')

      expect(await screen.findByRole('progressbar')).toBeInTheDocument()
      expect(await screen.findByRole('heading', { name: 'Asha Verma' })).toBeInTheDocument()
    })

    it('says so when the employee does not exist, and links back to the directory', async () => {
      server.use(
        http.get('*/api/employees/999', () =>
          HttpResponse.json({ error: { code: 'not_found', message: 'Employee not found' } }, { status: 404 }),
        ),
        http.get('*/api/employees/999/salary_changes', () =>
          HttpResponse.json({ error: { code: 'not_found', message: 'Employee not found' } }, { status: 404 }),
        ),
      )

      renderApp('/employees/999')

      expect(await screen.findByRole('heading', { name: 'Employee not found' })).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Back to employees' })).toHaveAttribute('href', '/employees')
    })

    it('reports any other failure, and loads again on request', async () => {
      let failing = true
      server.use(
        http.get('*/api/employees/7', () => (failing ? new HttpResponse(null, { status: 500 }) : HttpResponse.json({ data: asha() }))),
        http.get('*/api/employees/7/salary_changes', () => HttpResponse.json({ data: [] })),
      )
      const user = userEvent.setup()

      renderApp('/employees/7')

      expect(await screen.findByRole('alert')).toHaveTextContent('Could not load this employee: Request failed (500)')
      failing = false
      await user.click(screen.getByRole('button', { name: 'Try again' }))
      expect(await screen.findByRole('heading', { name: 'Asha Verma' })).toBeInTheDocument()
    })

    it('is reached by clicking a name in the directory', async () => {
      mockDirectory(() => pageOf([asha()]))
      mockEmployee()
      const user = userEvent.setup()

      renderApp('/employees')
      await user.click(await screen.findByRole('link', { name: 'Asha Verma' }))

      expect(await screen.findByRole('heading', { name: 'Asha Verma' })).toBeInTheDocument()
      expect(screen.getByTestId('location')).toHaveTextContent('/employees/7')
    })
  })

  describe('the salary history', () => {
    it('lists each change, newest first as the API sends them, with what it was and what it became', async () => {
      mockEmployee(asha(), [
        makeSalaryChange({
          effective_on: '2024-04-20', reason: 'Promotion',
          previous_salary: { amount: '80000.0', currency: 'USD' }, new_salary: { amount: '90000.0', currency: 'USD' },
        }),
        makeSalaryChange({
          effective_on: '2023-04-01', reason: 'Annual review',
          previous_salary: { amount: '76000.0', currency: 'USD' }, new_salary: { amount: '80000.0', currency: 'USD' },
        }),
      ])

      renderApp('/employees/7')

      const table = await screen.findByRole('table', { name: 'Salary history' })
      const rows = within(table).getAllByRole('row').slice(1) // without the header
      expect(rows).toHaveLength(2)
      for (const text of ['20 Apr 2024', '$80,000', '$90,000', '+12.5%', 'Promotion', 'hr@acme.example']) {
        expect(within(rows[0]).getByText(text)).toBeInTheDocument()
      }
      expect(within(rows[1]).getByText('1 Apr 2023')).toBeInTheDocument()
      expect(within(rows[1]).getByText('+5.3%')).toBeInTheDocument()
    })

    it('shows a change of currency without a percentage, since the two amounts are not comparable', async () => {
      mockEmployee(asha(), [
        makeSalaryChange({
          reason: 'Relocated to London',
          previous_salary: { amount: '70000.0', currency: 'EUR' }, new_salary: { amount: '60000.0', currency: 'GBP' },
        }),
      ])

      renderApp('/employees/7')

      const row = (await screen.findByText('Relocated to London')).closest('tr')!
      expect(within(row).getByText('€70,000')).toBeInTheDocument()
      expect(within(row).getByText('£60,000')).toBeInTheDocument()
      expect(within(row).getByText('—')).toBeInTheDocument()
    })

    it('shows history that was imported, and so has no author', async () => {
      mockEmployee(asha(), [makeSalaryChange({ changed_by: null })])

      renderApp('/employees/7')

      expect(await screen.findByText('Imported')).toBeInTheDocument()
    })

    it('says so when there is no history yet', async () => {
      mockEmployee(asha(), [])

      renderApp('/employees/7')

      expect(await screen.findByText('No salary changes have been recorded yet.')).toBeInTheDocument()
    })

    it('reports a failure to load the history without hiding the profile', async () => {
      server.use(
        http.get('*/api/employees/7', () => HttpResponse.json({ data: asha() })),
        http.get('*/api/employees/7/salary_changes', () => new HttpResponse(null, { status: 500 })),
      )

      renderApp('/employees/7')

      expect(await screen.findByRole('heading', { name: 'Asha Verma' })).toBeInTheDocument()
      expect(await screen.findByText('Could not load the salary history: Request failed (500)')).toBeInTheDocument()
    })
  })
})
