import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { hr, renderApp, signedIn, signedOut } from './test/helpers'
import { server } from './test/server'

describe('access to the app', () => {
  it('sends a signed-out visitor to the sign-in page', async () => {
    signedOut()

    renderApp('/employees')

    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
  })

  it('shows a loading indicator while it checks the session', async () => {
    signedIn()

    renderApp('/employees')

    expect(screen.getByRole('progressbar')).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('does not mistake a server error for being signed out, and lets the user try again', async () => {
    let calls = 0
    server.use(
      http.get('*/api/session', () =>
        ++calls === 1 ? new HttpResponse(null, { status: 500 }) : HttpResponse.json({ user: hr }),
      ),
    )
    const user = userEvent.setup()

    renderApp('/employees')

    expect(await screen.findByText('Could not check your session: Request failed (500)')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Try again' }))
    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('takes a signed-in user straight past the sign-in page', async () => {
    signedIn()

    renderApp('/login')

    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('opens on the employee directory', async () => {
    signedIn()

    renderApp('/')

    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('says so when a page does not exist', async () => {
    signedIn()

    renderApp('/nowhere')

    expect(await screen.findByRole('heading', { name: 'Page not found' })).toBeInTheDocument()
  })
})

describe('signing in', () => {
  async function fillAndSubmit(user: ReturnType<typeof userEvent.setup>, email: string, password: string) {
    await screen.findByRole('heading', { name: 'Sign in' })
    if (email) await user.type(screen.getByLabelText('Email'), email)
    if (password) await user.type(screen.getByLabelText('Password'), password)
    await user.click(screen.getByRole('button', { name: 'Sign in' }))
  }

  it('signs in with the given credentials and lands on the directory', async () => {
    signedOut()
    let sent: unknown
    server.use(
      http.post('*/api/session', async ({ request }) => {
        sent = await request.json()
        return HttpResponse.json({ user: hr }, { status: 201 })
      }),
    )
    const user = userEvent.setup()

    renderApp('/employees')
    await fillAndSubmit(user, 'hr@acme.example', 'correct-horse-battery')

    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
    expect(sent).toEqual({ email: 'hr@acme.example', password: 'correct-horse-battery' })
  })

  it('returns to the page the visitor first asked for', async () => {
    signedOut()
    server.use(http.post('*/api/session', () => HttpResponse.json({ user: hr }, { status: 201 })))
    const user = userEvent.setup()

    renderApp('/insights')
    await fillAndSubmit(user, 'hr@acme.example', 'correct-horse-battery')

    expect(await screen.findByRole('heading', { name: 'Insights' })).toBeInTheDocument()
  })

  it('asks for the email and password before sending anything', async () => {
    signedOut()
    let posted = false
    server.use(http.post('*/api/session', () => ((posted = true), HttpResponse.json({ user: hr }, { status: 201 }))))
    const user = userEvent.setup()

    renderApp('/employees')
    await fillAndSubmit(user, '', '')

    expect(await screen.findByText('Enter your email')).toBeInTheDocument()
    expect(screen.getByText('Enter your password')).toBeInTheDocument()
    expect(posted).toBe(false)
  })

  it('says the credentials are wrong without saying which one', async () => {
    signedOut()
    server.use(
      http.post('*/api/session', () =>
        HttpResponse.json(
          { error: { code: 'invalid_credentials', message: 'Invalid email or password' } },
          { status: 401 },
        ),
      ),
    )
    const user = userEvent.setup()

    renderApp('/employees')
    await fillAndSubmit(user, 'hr@acme.example', 'wrong-password')

    expect(await screen.findByRole('alert')).toHaveTextContent('Invalid email or password')
    expect(screen.getByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
  })

  it('explains when there have been too many attempts', async () => {
    signedOut()
    server.use(
      http.post('*/api/session', () =>
        HttpResponse.json({ error: { code: 'rate_limited', message: 'Too many login attempts.' } }, { status: 429 }),
      ),
    )
    const user = userEvent.setup()

    renderApp('/employees')
    await fillAndSubmit(user, 'hr@acme.example', 'whatever-123')

    expect(await screen.findByRole('alert')).toHaveTextContent('Too many attempts. Please wait a few minutes and try again.')
  })

  it('explains when the server cannot be reached', async () => {
    signedOut()
    server.use(http.post('*/api/session', () => HttpResponse.error()))
    const user = userEvent.setup()

    renderApp('/employees')
    await fillAndSubmit(user, 'hr@acme.example', 'whatever-123')

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not reach the server')
  })
})

describe('the signed-in shell', () => {
  it('shows who is signed in', async () => {
    signedIn()

    renderApp('/employees')

    expect(await screen.findByText('hr@acme.example')).toBeInTheDocument()
  })

  it('marks the current page in the navigation and moves between pages', async () => {
    signedIn()
    const user = userEvent.setup()

    renderApp('/employees')

    expect(await screen.findByRole('link', { name: 'Employees' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'Insights' })).not.toHaveAttribute('aria-current')

    await user.click(screen.getByRole('link', { name: 'Insights' }))

    expect(await screen.findByRole('heading', { name: 'Insights' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Insights' })).toHaveAttribute('aria-current', 'page')
  })

  it('signs out, ends the session on the server and returns to the sign-in page', async () => {
    signedIn()
    let ended = false
    server.use(http.delete('*/api/session', () => ((ended = true), new HttpResponse(null, { status: 204 }))))
    const user = userEvent.setup()

    renderApp('/employees')
    await user.click(await screen.findByRole('button', { name: 'Sign out' }))

    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()
    expect(ended).toBe(true)
  })
})
