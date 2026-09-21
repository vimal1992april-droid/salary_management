# Salary Management

Web-based salary management for an organisation with **10,000 employees across multiple countries**. It replaces
the HR team's Excel files: the HR Manager can find and maintain salary data, and answer questions about
**how the organisation pays its people**.

> **Status: built and tested end to end.** The Rails API, the React app, the Docker image and the deployment
> blueprint are done and were checked with a real browser against the production image. Still to do by the owner:
> deploy it (see [docs/deployment.md](docs/deployment.md)) and record the demo video.

- **Live demo:** _not deployed yet_ (needs a Render account; the blueprint is ready)
- **Demo video:** _not recorded yet_

| Directory | Insights |
|---|---|
| ![The employee directory](docs/screenshots/directory.png) | ![The insights dashboard](docs/screenshots/insights.png) |

| Change a salary | Salary history |
|---|---|
| ![Changing a salary](docs/screenshots/change-salary.png) | ![An employee's salary history](docs/screenshots/salary-history.png) |

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
  (green): 23 red/green pairs in the history, with the bugs the tests and tools found fixed in the commit that
  follows them. There are about 1,400 lines of backend code and 2,500 lines of backend tests.
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

Sign in at http://localhost:5173 with **`hr@acme.example` / `salary-manager-demo`** (created by `db:seed` in
development; elsewhere set `HR_EMAIL` and `HR_PASSWORD`). `db:seed` is safe to run again, and
`SEED_EMPLOYEES=500 bin/rails db:seed` seeds fewer.

The API can also be used directly:

```bash
curl -c cookies.txt -H 'Content-Type: application/json' \
     -d '{"email":"hr@acme.example","password":"salary-manager-demo"}' http://localhost:3000/api/session
curl -b cookies.txt 'http://localhost:3000/api/insights/salary_stats?group_by=country'
curl -b cookies.txt 'http://localhost:3000/api/insights/outliers?limit=10'
curl -b cookies.txt -o employees.csv 'http://localhost:3000/api/employees/export?status=active'
```

## Running the whole product as one image

```bash
docker build -t salary-management .
docker network create sm-net
docker run -d --name sm-pg --network sm-net -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=salary_management postgres:17
docker run -p 8080:3000 --network sm-net \
  -e DATABASE_URL=postgres://postgres:postgres@sm-pg:5432/salary_management \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) -e HR_EMAIL=hr@example.com -e HR_PASSWORD=choose-one \
  -e FORCE_SSL=false salary-management        # FORCE_SSL=false only because this is plain HTTP
```

It migrates and seeds on first start, then serves the app at http://localhost:8080.

## Running the tests

```bash
cd backend  && bin/rails test && bin/rubocop && bin/brakeman     # 264 tests in about 5 s
cd frontend && npm test && npm run lint && npm run build         # 155 tests in about 20 s
```

The browser tests (one test of the critical path, run against the production image) are described in
[e2e/README.md](e2e/README.md). To time every endpoint against a running server: `ruby backend/script/benchmark.rb`.

## Repository layout

```
backend/     Rails 8.1 API: app/ (controllers, models, queries, services, serializers), db/, test/, script/
frontend/    React + TypeScript app: src/ (api, auth, components, features, lib, test)
e2e/         Playwright browser tests
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
