import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { beforeEach, describe, expect, it } from 'vitest'
import type { Employee } from '../../api/employees'
import { makeEmployee } from '../../test/fixtures'
import { renderApp, signedIn } from '../../test/helpers'
import { server } from '../../test/server'

/** An employee whose status really changes when it is patched, as on the server. */
function mockEmployee(status: Employee['status'], options: { failure?: Response } = {}) {
  let employee = makeEmployee({ id: 7, full_name: 'Asha Verma', status })
  const patches: unknown[] = []
  server.use(
    http.get('*/api/employees/7', () => HttpResponse.json({ data: employee })),
    http.get('*/api/employees/7/salary_changes', () => HttpResponse.json({ data: [] })),
    http.patch('*/api/employees/7', async ({ request }) => {
      const body = (await request.json()) as { employee: { status: Employee['status'] } }
      patches.push(body)
      if (options.failure) return options.failure
      employee = { ...employee, status: body.employee.status }
      return HttpResponse.json({ data: employee })
    }),
  )
  return patches
}

describe('deactivating and reactivating an employee', () => {
  beforeEach(() => signedIn())

  it('asks for confirmation before deactivating, saying what it means', async () => {
    const patches = mockEmployee('active')
    const user = userEvent.setup()

    renderApp('/employees/7')
    await user.click(await screen.findByRole('button', { name: 'Deactivate' }))

    const dialog = screen.getByRole('dialog', { name: 'Deactivate Asha Verma?' })
    expect(within(dialog).getByText(/no longer counted in pay statistics/i)).toBeInTheDocument()
    expect(within(dialog).getByText(/history is kept/i)).toBeInTheDocument()
    expect(patches).toHaveLength(0)

    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(patches).toHaveLength(0)
  })

  it('deactivates once confirmed, and the page then offers to reactivate', async () => {
    const patches = mockEmployee('active')
    const user = userEvent.setup()

    renderApp('/employees/7')
    await user.click(await screen.findByRole('button', { name: 'Deactivate' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Deactivate' }))

    expect(await screen.findByText('Inactive')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Reactivate' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Deactivate' })).not.toBeInTheDocument()
    expect(screen.getByText('Employee deactivated').closest('[role="status"]')).not.toBeNull()
    expect(patches).toEqual([{ employee: { status: 'inactive' } }])
  })

  it('reactivates straight away, without asking', async () => {
    const patches = mockEmployee('inactive')
    const user = userEvent.setup()

    renderApp('/employees/7')
    await user.click(await screen.findByRole('button', { name: 'Reactivate' }))

    expect(await screen.findByText('Active')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Deactivate' })).toBeInTheDocument()
    expect(screen.getByText('Employee reactivated').closest('[role="status"]')).not.toBeNull()
    expect(patches).toEqual([{ employee: { status: 'active' } }])
  })

  it('reports a failure and leaves the status alone', async () => {
    mockEmployee('active', { failure: new HttpResponse(null, { status: 500 }) })
    const user = userEvent.setup()

    renderApp('/employees/7')
    await user.click(await screen.findByRole('button', { name: 'Deactivate' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Deactivate' }))

    expect(await within(screen.getByRole('dialog')).findByRole('alert')).toHaveTextContent('Request failed (500)')
    expect(screen.getByText('Active')).toBeInTheDocument()
  })
})
