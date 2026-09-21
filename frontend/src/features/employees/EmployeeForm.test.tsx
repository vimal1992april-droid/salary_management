import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { Employee } from '../../api/employees'
import { lookups, makeEmployee, pageOf } from '../../test/fixtures'
import { mockDirectory, renderApp, signedIn } from '../../test/helpers'
import { server } from '../../test/server'

type User = ReturnType<typeof userEvent.setup>

/** Serves employee 7 (for the edit page), the lookups, and records the bodies of POSTs and PATCHes. */
function mockServer(options: { failure?: Response } = {}) {
  const sent: { method: string; body: unknown }[] = []
  let employee: Employee = makeEmployee({ id: 7, first_name: 'Asha', last_name: 'Verma', full_name: 'Asha Verma', employee_number: 'E00007' })

  server.use(
    http.get('*/api/lookups', () => HttpResponse.json(lookups)),
    http.get('*/api/employees/7', () => HttpResponse.json({ data: employee })),
    http.get('*/api/employees/7/salary_changes', () => HttpResponse.json({ data: [] })),
    http.get('*/api/employees/42', () => HttpResponse.json({ data: makeEmployee({ id: 42, full_name: 'Nikhil Rao' }) })),
    http.get('*/api/employees/42/salary_changes', () => HttpResponse.json({ data: [] })),
    http.get('*/api/employees/999', () => HttpResponse.json({ error: { code: 'not_found', message: 'Employee not found' } }, { status: 404 })),
    http.post('*/api/employees', async ({ request }) => {
      sent.push({ method: 'POST', body: await request.json() })
      return options.failure ?? HttpResponse.json({ data: makeEmployee({ id: 42, full_name: 'Nikhil Rao' }) }, { status: 201 })
    }),
    http.patch('*/api/employees/7', async ({ request }) => {
      const body = (await request.json()) as { employee: Partial<Employee> }
      sent.push({ method: 'PATCH', body })
      if (options.failure) return options.failure
      employee = { ...employee, ...body.employee } as Employee
      employee.full_name = `${employee.first_name} ${employee.last_name}` // as the API's serializer does
      return HttpResponse.json({ data: employee })
    }),
  )
  return sent
}

/** Puts text into a field in one step: much faster than typing each character through MUI. */
async function enter(user: User, label: string, text: string) {
  await user.click(screen.getByLabelText(label))
  await user.paste(text)
}

async function fillNewEmployee(user: User) {
  await screen.findByRole('option', { name: 'India' }) // the lookups have loaded
  await enter(user, 'Employee number', 'E90001')
  await enter(user, 'First name', 'Nikhil')
  await enter(user, 'Last name', 'Rao')
  await enter(user, 'Email', 'nikhil.rao@acme.example')
  await user.selectOptions(screen.getByLabelText('Country'), 'India')
  await user.selectOptions(screen.getByLabelText('Department'), 'Sales')
  await user.selectOptions(screen.getByLabelText('Job title'), 'Account Executive')
  await enter(user, 'Hire date', '2026-05-01')
  await enter(user, 'Starting salary', '1500000')
}

beforeEach(() => {
  signedIn()
  vi.useFakeTimers({ toFake: ['Date'] }) // only the date, so today is fixed while timers still run
  vi.setSystemTime(new Date(2026, 8, 21, 12))
})
afterEach(() => vi.useRealTimers())

describe('adding an employee', () => {
  it('is reached from the directory', async () => {
    mockDirectory(() => pageOf([makeEmployee()]))
    mockServer()
    const user = userEvent.setup()

    renderApp('/employees')
    await user.click(await screen.findByRole('link', { name: 'Add employee' }))

    expect(await screen.findByRole('heading', { name: 'Add employee' })).toBeInTheDocument()
  })

  it('checks the form before sending anything', async () => {
    const sent = mockServer()
    const user = userEvent.setup()

    renderApp('/employees/new')
    await user.click(await screen.findByRole('button', { name: 'Add employee' }))

    expect(await screen.findByText('Enter an employee number')).toBeInTheDocument()
    expect(screen.getByText('Choose a country')).toBeInTheDocument()
    expect(screen.getByText('Enter the starting salary')).toBeInTheDocument()
    expect(sent).toHaveLength(0)
  })

  it("clears a field's message as soon as it is edited, and leaves the others", async () => {
    mockServer()
    const user = userEvent.setup()

    renderApp('/employees/new')
    await user.click(await screen.findByRole('button', { name: 'Add employee' }))
    expect(await screen.findByText('Enter an employee number')).toBeInTheDocument()

    await enter(user, 'Employee number', 'E90001')

    expect(screen.queryByText('Enter an employee number')).not.toBeInTheDocument()
    expect(screen.getByText('Enter a first name')).toBeInTheDocument()
  })

  it('brings back the currency hint once the salary message is gone', async () => {
    mockServer()
    const user = userEvent.setup()

    renderApp('/employees/new')
    await user.click(await screen.findByRole('button', { name: 'Add employee' }))
    expect(await screen.findByText('Enter the starting salary')).toBeInTheDocument()

    await screen.findByRole('option', { name: 'India' })
    await user.selectOptions(screen.getByLabelText('Country'), 'India')
    await enter(user, 'Starting salary', '1500000')

    expect(screen.queryByText('Enter the starting salary')).not.toBeInTheDocument()
    expect(screen.getByText('Paid in INR')).toBeInTheDocument()
  })

  it('says which currency the salary will be in, once a country is chosen', async () => {
    mockServer()
    const user = userEvent.setup()

    renderApp('/employees/new')
    expect(await screen.findByText('Paid in the currency of the country you choose')).toBeInTheDocument()

    await screen.findByRole('option', { name: 'India' })
    await user.selectOptions(screen.getByLabelText('Country'), 'India')

    expect(screen.getByText('Paid in INR')).toBeInTheDocument()
  })

  it('creates the employee and opens their page with a confirmation', async () => {
    const sent = mockServer()
    const user = userEvent.setup()

    renderApp('/employees/new')
    await fillNewEmployee(user)
    await user.click(screen.getByRole('button', { name: 'Add employee' }))

    expect(await screen.findByRole('heading', { name: 'Nikhil Rao' })).toBeInTheDocument()
    expect(screen.getByTestId('location')).toHaveTextContent('/employees/42')
    expect(screen.getByText('Employee added').closest('[role="status"]')).not.toBeNull()
    expect(sent).toEqual([
      {
        method: 'POST',
        body: {
          employee: {
            employee_number: 'E90001', first_name: 'Nikhil', last_name: 'Rao', email: 'nikhil.rao@acme.example',
            country_id: '2', department_id: '2', job_title_id: '2', hire_date: '2026-05-01', salary_amount: '1500000',
          },
        },
      },
    ])
  })

  it('shows the server\'s messages beside the fields, and keeps what was typed', async () => {
    mockServer({
      failure: HttpResponse.json(
        { error: { code: 'validation_failed', message: 'Validation failed', details: { email: ['has already been taken'] } } },
        { status: 422 },
      ),
    })
    const user = userEvent.setup()

    renderApp('/employees/new')
    await fillNewEmployee(user)
    await user.click(screen.getByRole('button', { name: 'Add employee' }))

    expect(await screen.findByText('Has already been taken')).toBeInTheDocument()
    expect(screen.getByLabelText('Email')).toHaveValue('nikhil.rao@acme.example')
    expect(screen.getByLabelText('First name')).toHaveValue('Nikhil')
  })

  it("clears the server's message for a field once that field is edited", async () => {
    mockServer({
      failure: HttpResponse.json(
        { error: { code: 'validation_failed', message: 'Validation failed', details: { email: ['has already been taken'] } } },
        { status: 422 },
      ),
    })
    const user = userEvent.setup()

    renderApp('/employees/new')
    await fillNewEmployee(user)
    await user.click(screen.getByRole('button', { name: 'Add employee' }))
    expect(await screen.findByText('Has already been taken')).toBeInTheDocument()

    await user.click(screen.getByLabelText('Email'))
    await user.paste('x')

    expect(screen.queryByText('Has already been taken')).not.toBeInTheDocument()
  })

  it('reports any other failure above the form', async () => {
    mockServer({ failure: new HttpResponse(null, { status: 500 }) })
    const user = userEvent.setup()

    renderApp('/employees/new')
    await fillNewEmployee(user)
    await user.click(screen.getByRole('button', { name: 'Add employee' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Request failed (500)')
  })

  it('goes back to the directory when cancelled', async () => {
    mockServer()
    mockDirectory(() => pageOf([]))
    const user = userEvent.setup()

    renderApp('/employees/new')
    await user.click(await screen.findByRole('link', { name: 'Cancel' }))

    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })
})

describe('editing an employee', () => {
  it('is reached from their page', async () => {
    mockServer()
    const user = userEvent.setup()

    renderApp('/employees/7')
    await user.click(await screen.findByRole('link', { name: 'Edit' }))

    expect(await screen.findByRole('heading', { name: 'Edit Asha Verma' })).toBeInTheDocument()
  })

  it('starts with the employee\'s details, and offers no salary or employee number to change', async () => {
    mockServer()

    renderApp('/employees/7/edit')

    await waitFor(() => expect(screen.getByLabelText('First name')).toHaveValue('Asha'))
    expect(screen.getByLabelText('Last name')).toHaveValue('Verma')
    expect(screen.getByLabelText('Email')).toHaveValue('asha.verma@acme.example')
    expect(screen.getByLabelText('Hire date')).toHaveValue('2022-03-01')
    expect(screen.getByText('E00007')).toBeInTheDocument()
    expect(screen.queryByLabelText('Employee number')).not.toBeInTheDocument()
    expect(screen.queryByLabelText('Starting salary')).not.toBeInTheDocument()
    expect(screen.getByText(/salary is changed from the employee's page/i)).toBeInTheDocument()
  })

  it('saves only what can change, and returns to their page with a confirmation', async () => {
    const sent = mockServer()
    const user = userEvent.setup()

    renderApp('/employees/7/edit')
    const firstName = await screen.findByLabelText('First name')
    await waitFor(() => expect(firstName).toHaveValue('Asha'))
    await user.clear(firstName)
    await user.type(firstName, 'Ashaa')
    await user.click(screen.getByRole('button', { name: 'Save changes' }))

    expect(await screen.findByRole('heading', { name: 'Ashaa Verma' })).toBeInTheDocument()
    expect(screen.getByText('Employee updated').closest('[role="status"]')).not.toBeNull()
    expect(sent).toHaveLength(1)
    expect(Object.keys((sent[0].body as { employee: object }).employee).sort()).toEqual([
      'country_id', 'department_id', 'email', 'first_name', 'hire_date', 'job_title_id', 'last_name',
    ])
  })

  it('checks the form before sending', async () => {
    const sent = mockServer()
    const user = userEvent.setup()

    renderApp('/employees/7/edit')
    const email = await screen.findByLabelText('Email')
    await waitFor(() => expect(email).toHaveValue('asha.verma@acme.example'))
    await user.clear(email)
    await user.type(email, 'not-an-email')
    await user.click(screen.getByRole('button', { name: 'Save changes' }))

    expect(await screen.findByText('Enter a valid email address')).toBeInTheDocument()
    expect(sent).toHaveLength(0)
  })

  it('says so when the employee does not exist', async () => {
    mockServer()

    renderApp('/employees/999/edit')

    expect(await screen.findByRole('heading', { name: 'Employee not found' })).toBeInTheDocument()
  })
})
