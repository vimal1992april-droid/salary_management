# Salary Management

Web-based salary management for an organisation with **10,000 employees across multiple countries**. It replaces
the HR team's Excel files: the HR Manager can find and maintain salary data, and answer questions about
**how the organisation pays its people**.

> **Status: built and tested end to end.** The Rails API, the React app, the Docker image and the deployment
> blueprint are done and were checked with a real browser against the production image. Still to do by the owner:
> deploy it (see [docs/deployment.md](docs/deployment.md)) and record the demo video.

- **Live demo:** _not deployed yet_ (needs a Render account; the blueprint is ready)
- **Logins:** HR manager and administrator, see [Signing in](#signing-in)
- **Demo video:** _not recorded yet_

| Directory | Insights |
|---|---|
| ![The employee directory](docs/screenshots/directory.png) | ![The insights dashboard](docs/screenshots/insights.png) |

| Change a salary | Salary history |
|---|---|
| ![Changing a salary](docs/screenshots/change-salary.png) | ![An employee's salary history](docs/screenshots/salary-history.png) |

And the administrator's panel at `/admin` ([docs/admin.md](docs/admin.md)):

| Dashboard | API monitor |
|---|---|
| ![The admin dashboard](docs/screenshots/admin-dashboard.png) | ![The API monitor](docs/screenshots/admin-api-monitor.png) |

## What it does

For the HR Manager (a single role; everything needs a login):

- **Employee directory:** search by name, email or number; filter by country, department, job title and status;
  sort; page through 10,000 people quickly. The whole view lives in the URL, so a link or a refresh shows the same
  thing. **Export the current view as CSV.**
- **Maintain records:** add and edit employees; deactivate instead of deleting, so history is kept.
- **Salary changes with history:** every change records the old and new amount (and currency), when it took effect,
  why, and who made it. The history is append-only.
- **Insights:** headcount and payroll; the pay range (lowest, 25th percentile, median, 75th percentile, highest,
  average) by country, department or job title; how salaries are distributed; the highest and lowest paid; and
  **outliers**, people paid far outside their peers (same job title, same country). Figures that compare pay across
  countries are converted to USD at a static, dated exchange rate.

For the administrator (a separate login, at **`/admin`**, server-rendered by Rails; see [docs/admin.md](docs/admin.md)):

- **All the data:** every table, read-only, with search, sorting, paging and links between related records.
  Password digests are never shown.
- **Graphs:** headcount by department and country, hires per year, salary changes per month, the salary
  distribution and active against inactive, drawn as SVG on the server.
- **API monitor:** every API endpoint with its state (idle, healthy, degraded, failing), a live database check,
  and a log of every call with its **payload and response** (secrets are filtered before anything is stored).

What is deliberately **not** included (payroll, RBAC, live exchange rates, pay-equity analysis, CSV import, …) and
why is in [docs/requirements.md](docs/requirements.md).

## How it is built

| Layer | Choice |
|---|---|
| Backend | Ruby 3.4, **Rails 8.1** (API-only), PostgreSQL |
| Frontend | **React 19 + TypeScript** (Vite), MUI, TanStack Query, React Router, Recharts |
| Tests | Minitest + FactoryBot (backend), Vitest + Testing Library + MSW (frontend), Playwright (browser) |
| Delivery | GitHub Actions CI; one multi-stage Docker image in which Rails serves the built React app |

- **Test-driven.** Each feature is a `test:` commit that fails (red) followed by a `feat:` commit that makes it pass
  (green): 37 red commits in the history, each followed by the commit that makes it pass, with the bugs the tests
  and tools found fixed in the commit that follows them. There are about 3,000 lines of backend code (Ruby and
  views) and 4,900 lines of backend tests.
- **Statistics are computed in SQL** (`percentile_cont`, `GROUP BY`, a CTE for outliers), never in Ruby or the
  browser; the frontend only renders what the API returns. Every interactive endpoint responds in under 60 ms at
  p95 with 10,000 employees ([measurements](docs/performance.md)).
- **One origin.** Rails serves the API and the built React app, so the httpOnly session cookie works without CORS
  and there is one thing to deploy.
- **Deterministic seed:** `bin/rails db:seed` creates exactly 10,000 employees and about 10,000 salary changes,
  the same every time.

## Documentation

| Document | What is in it |
|---|---|
| [docs/requirements.md](docs/requirements.md) | One-page requirements: goal, scope, what is left out and why |
| [docs/admin.md](docs/admin.md) | The administrator's panel: sign-in, data browser, graphs, the API monitor, and what it records and keeps |
| [docs/implementation-plan.md](docs/implementation-plan.md) | Architecture, data model, API, TDD strategy, milestones and their status, and §17: what changed while building |
| [docs/performance.md](docs/performance.md) | Measurements against 10,000 employees, `EXPLAIN` plans, what was deliberately not optimised |
| [docs/deployment.md](docs/deployment.md) | Deploying the image (Render blueprint), the environment variables, and what was and was not verified |
| [docs/ai-usage.md](docs/ai-usage.md) | How AI was used, what it got wrong, and how each mistake was caught |
| [e2e/README.md](e2e/README.md) | The browser tests and how to run them |

## Getting started (development)

**Requirements:** Ruby 3.4 (the version in `backend/.ruby-version`; with rbenv, `rbenv install 3.4.6`), Node 20+,
PostgreSQL 16 with a local role that can create databases.

```bash
cd backend
bundle install
bin/rails db:create db:migrate
bin/rails db:seed        # 10,000 employees + salary history + the HR login, about 4 s
bin/rails server         # API  http://localhost:3000

cd frontend               # in another terminal
npm install
npm run dev               # app  http://localhost:5173 (proxies /api to Rails)
```

Then sign in (see [Signing in](#signing-in) for both logins): the HR app at http://localhost:5173 with
**`hr@acme.example` / `salary-manager-demo`**, and the administrator's panel at http://localhost:3000/admin with
**`admin@acme.example` / `admin-panel-demo`**. `db:seed` is safe to run again, and
`SEED_EMPLOYEES=500 bin/rails db:seed` seeds fewer.

The API can also be used directly:

```bash
curl -c cookies.txt -H 'Content-Type: application/json' \
     -d '{"email":"hr@acme.example","password":"salary-manager-demo"}' http://localhost:3000/api/session
curl -b cookies.txt 'http://localhost:3000/api/insights/salary_stats?group_by=country'
curl -b cookies.txt 'http://localhost:3000/api/insights/outliers?limit=10'
curl -b cookies.txt -o employees.csv 'http://localhost:3000/api/employees/export?status=active'
```

## Signing in

There are **two separate logins**. They are different accounts with different cookies: the HR login cannot open the
admin panel, and the admin login cannot open the HR app or its API.

| | HR manager | Administrator |
|---|---|---|
| What it opens | The React app: employees, salary changes, insights | The Rails admin panel: all the data, graphs and the API monitor ([docs/admin.md](docs/admin.md)) |
| Local development | http://localhost:5173 | http://localhost:3000/admin |
| Email | `hr@acme.example` | `admin@acme.example` |
| Password | `salary-manager-demo` | `admin-panel-demo` |
| Set them yourself | `HR_EMAIL`, `HR_PASSWORD` | `ADMIN_EMAIL`, `ADMIN_PASSWORD` |

**Local development.** Both demo logins are created by `bin/rails db:seed` (and only in development; the demo
passwords are never created anywhere else). Start Rails (`bin/rails server`, port 3000) and, for the HR app, the
frontend (`npm run dev`, port 5173), then open the address in the table. If the login page says *Invalid email or
password*, the login has not been created yet: run `bin/rails db:seed`.

**The Docker image** (see below) serves both on one port: the HR app at http://localhost:8080 and the admin panel at
http://localhost:8080/admin, with the emails and passwords you passed as `HR_EMAIL`, `HR_PASSWORD`, `ADMIN_EMAIL` and
`ADMIN_PASSWORD`. **On Render** it is the same, at your service's address and `/admin`, with the four values you entered
when creating the blueprint ([docs/deployment.md](docs/deployment.md)).

Good to know:

- Outside development there are no default logins: a login exists only if its two variables are set. They are read
  on every start (and by `db:seed`), so changing the variable and restarting also **resets that password**.
- To choose your own in development: `ADMIN_EMAIL=me@example.com ADMIN_PASSWORD=a-long-password bin/rails db:seed`
  (and the same with `HR_EMAIL` and `HR_PASSWORD`).
- To make an existing user an administrator, in `bin/rails console`:
  `User.find_by!(email: "someone@example.com").update!(admin: true)`. Removing it (`admin: false`) ends their access to
  the panel at once.
- The admin session lasts 8 hours, the HR session 14 days. After 10 failed attempts in 3 minutes from one address,
  sign-in is refused for a while.
- After pulling new code, **restart the Rails server**: it reads its configuration and new directories only when it
  starts, and a server left running from before the admin panel was added will fail with errors such as
  `uninitialized constant AdminHelper`.

## Running the whole product as one image

```bash
docker build -t salary-management .
docker network create sm-net
docker run -d --name sm-pg --network sm-net -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=salary_management postgres:17
docker run -p 8080:3000 --network sm-net \
  -e DATABASE_URL=postgres://postgres:postgres@sm-pg:5432/salary_management \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) -e HR_EMAIL=hr@example.com -e HR_PASSWORD=choose-one \
  -e ADMIN_EMAIL=admin@example.com -e ADMIN_PASSWORD=choose-another \
  -e FORCE_SSL=false salary-management        # FORCE_SSL=false only because this is plain HTTP
```

It migrates and seeds on first start, then serves the HR app at http://localhost:8080 and the admin panel at
http://localhost:8080/admin (sign in with the emails and passwords passed above; see [Signing in](#signing-in)).

## Running the tests

```bash
cd backend  && bin/rails test && bin/rubocop && bin/brakeman     # 487 tests in about 7 s
cd frontend && npm test && npm run lint && npm run build         # 155 tests in about 20 s
```

The browser tests (two tests, the HR manager's critical path and the administrator's panel, run against the production image) are described in
[e2e/README.md](e2e/README.md). To time every endpoint against a running server: `ruby backend/script/benchmark.rb`.

## Repository layout

```
backend/     Rails 8.1 API: app/ (controllers, models, queries, services, serializers), db/, test/, script/
frontend/    React + TypeScript app: src/ (api, auth, components, features, lib, test)
e2e/         Playwright browser tests (the HR app and the admin panel)
docs/        Requirements, plan, performance, deployment, AI usage, screenshots
Dockerfile   The production image; render.yaml is the Render blueprint
.github/     CI workflow and Dependabot config
```

## What has and has not been verified

- **Verified:** all backend and frontend tests, RuboCop, Brakeman, lint and the build, in clean containers on the
  Ruby and Node versions CI uses; the production image built and run against a real Postgres; the browser test
  passing against that image; and the frontend's test fixtures compared with the real API's responses (all 17
  request shapes match).
- **Not yet done:** a run of the GitHub Actions workflow on GitHub, a deploy to a real host, and the demo video.
- **Known limits:** the main JavaScript bundle is about 600 kB (MUI, React Query and the router; the chart library
  is a separate lazily loaded chunk), and the frontend suite takes about 20 s, over the 15 s the plan aimed for,
  because MUI renders slowly in jsdom.
