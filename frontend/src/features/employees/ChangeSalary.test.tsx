import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { delay, http, HttpResponse } from 'msw'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { Employee } from '../../api/employees'
import type { SalaryChange } from '../../api/salaryChanges'
import { lookups, makeEmployee, makeSalaryChange } from '../../test/fixtures'
import { renderApp, signedIn } from '../../test/helpers'
import { server } from '../../test/server'

const asha = () =>
  makeEmployee({ id: 7, full_name: 'Asha Verma', hire_date: '2022-03-01', salary: { amount: '90000.0', currency: 'USD', usd: '90000.0' } })

/** An employee whose salary really changes when a change is posted, as on the server. */
function mockEmployee(options: { onPost?: (body: unknown) => Response | undefined } = {}) {
  let employee: Employee = asha()
  let history: SalaryChange[] = []
  const posted: unknown[] = []

  server.use(
    http.get('*/api/lookups', () => HttpResponse.json(lookups)),
    http.get('*/api/employees/7', () => HttpResponse.json({ data: employee })),
    http.get('*/api/employees/7/salary_changes', () => HttpResponse.json({ data: history })),
    http.post('*/api/employees/7/salary_changes', async ({ request }) => {
      const body = (await request.json()) as { salary_change: { new_amount: string; currency_code: string; reason: string; effective_on: string } }
      posted.push(body)
      const failure = options.onPost?.(body)
      if (failure) return failure

      const { new_amount: amount, currency_code: currency, reason, effective_on } = body.salary_change
      const change = makeSalaryChange({
        effective_on, reason,
        previous_salary: employee.salary, new_salary: { amount: `${amount}.0`, currency },
      })
      history = [change, ...history]
      employee = { ...employee, salary: { amount: `${amount}.0`, currency, usd: `${amount}.0` } }
      return HttpResponse.json({ data: change, employee }, { status: 201 })
    }),
  )
  return posted
}

async function openDialog(user: ReturnType<typeof userEvent.setup>) {
  renderApp('/employees/7')
  await user.click(await screen.findByRole('button', { name: 'Change salary' }))
  return screen.getByRole('dialog', { name: 'Change salary' })
}

describe('changing an employee\'s salary', () => {
  beforeEach(() => {
    signedIn()
    // Only the date is faked, so timers and promises still run normally.
    vi.useFakeTimers({ toFake: ['Date'] })
    vi.setSystemTime(new Date(2026, 8, 21, 12))
  })
  afterEach(() => vi.useRealTimers())

  it('opens a form showing the current salary, today\'s date and the current currency', async () => {
    mockEmployee()
    const user = userEvent.setup()

    const dialog = await openDialog(user)

    expect(within(dialog).getByText('Current salary: $90,000')).toBeInTheDocument()
    expect(within(dialog).getByLabelText('New salary')).toHaveValue('')
    expect(within(dialog).getByLabelText('Effective date')).toHaveValue('2026-09-21')
    await waitFor(() => expect(within(dialog).getByLabelText('Currency')).toHaveValue('USD'))
  })

  it('closes without sending anything when cancelled', async () => {
    const posted = mockEmployee()
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(posted).toHaveLength(0)
  })

  it('checks the form before sending anything, and lists every problem', async () => {
    const posted = mockEmployee()
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    expect(await within(dialog).findByText('Enter the new salary')).toBeInTheDocument()
    expect(within(dialog).getByText('Give a reason for the change')).toBeInTheDocument()
    expect(posted).toHaveLength(0)
  })

  it('refuses a salary that is the same as the current one', async () => {
    const posted = mockEmployee()
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.type(within(dialog).getByLabelText('New salary'), '90000')
    await user.type(within(dialog).getByLabelText('Reason'), 'No change')
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    expect(await within(dialog).findByText('This is the same as the current salary')).toBeInTheDocument()
    expect(posted).toHaveLength(0)
  })

  it('records the change, closes, and shows the new salary and the new history entry', async () => {
    const posted = mockEmployee()
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.type(within(dialog).getByLabelText('New salary'), '110000')
    await user.type(within(dialog).getByLabelText('Reason'), 'Annual review')
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(posted).toEqual([
      { salary_change: { new_amount: '110000', currency_code: 'USD', effective_on: '2026-09-21', reason: 'Annual review' } },
    ])
    expect(await screen.findByText('$110,000', { selector: 'p' })).toBeInTheDocument() // the current salary
    expect(await screen.findByRole('table', { name: 'Salary history' })).toBeInTheDocument()
    expect(screen.getByText('Annual review')).toBeInTheDocument()
    expect(screen.getByRole('status')).toHaveTextContent('Salary updated')
  })

  it('can change the currency along with the amount', async () => {
    const posted = mockEmployee()
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.type(within(dialog).getByLabelText('New salary'), '5000000')
    await waitFor(() => expect(within(dialog).getByRole('option', { name: /INR/ })).toBeInTheDocument())
    await user.selectOptions(within(dialog).getByLabelText('Currency'), 'INR')
    await user.type(within(dialog).getByLabelText('Reason'), 'Relocated to Pune')
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    await waitFor(() => expect(posted).toHaveLength(1))
    expect(posted[0]).toMatchObject({ salary_change: { new_amount: '5000000', currency_code: 'INR' } })
  })

  it('shows the server\'s validation messages next to the fields, and keeps what was typed', async () => {
    mockEmployee({
      onPost: () =>
        HttpResponse.json(
          { error: { code: 'validation_failed', message: 'Validation failed', details: { new_amount: ['must differ from the current salary'], reason: ['is too long'] } } },
          { status: 422 },
        ),
    })
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.type(within(dialog).getByLabelText('New salary'), '110000')
    await user.type(within(dialog).getByLabelText('Reason'), 'Annual review')
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    expect(await within(dialog).findByText('Must differ from the current salary')).toBeInTheDocument()
    expect(within(dialog).getByText('Is too long')).toBeInTheDocument()
    expect(within(dialog).getByLabelText('New salary')).toHaveValue('110000')
    expect(within(dialog).getByLabelText('Reason')).toHaveValue('Annual review')
  })

  it('reports any other failure inside the form, which stays open', async () => {
    mockEmployee({ onPost: () => new HttpResponse(null, { status: 500 }) })
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.type(within(dialog).getByLabelText('New salary'), '110000')
    await user.type(within(dialog).getByLabelText('Reason'), 'Annual review')
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Request failed (500)')
    expect(screen.getByRole('dialog', { name: 'Change salary' })).toBeInTheDocument()
  })

  it('cannot be submitted twice while it is saving', async () => {
    mockEmployee({
      onPost: () => undefined,
    })
    server.use(
      http.post('*/api/employees/7/salary_changes', async () => {
        await delay(300)
        return HttpResponse.json({ error: { code: 'validation_failed', message: 'Validation failed' } }, { status: 422 })
      }),
    )
    const user = userEvent.setup()

    const dialog = await openDialog(user)
    await user.type(within(dialog).getByLabelText('New salary'), '110000')
    await user.type(within(dialog).getByLabelText('Reason'), 'Annual review')
    await user.click(within(dialog).getByRole('button', { name: 'Save change' }))

    expect(await within(dialog).findByRole('button', { name: 'Saving…' })).toBeDisabled()
  })
})
