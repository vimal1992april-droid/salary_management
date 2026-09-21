# Salary Management

Web-based salary management for an organisation with **10,000 employees across multiple countries**.
It replaces the HR team's Excel files. The HR Manager can find and maintain salary data and answer
questions about **how the organisation pays its people**.

> **Status: the backend is built and tested; the React frontend and deployment are next.** The API does
> everything below, and you can use it today with `curl`. The frontend is still the empty scaffold that
> checks the API's health. This README is updated as each piece lands.

- **Live demo:** _not deployed yet_
- **Demo video:** _not recorded yet_

## What the API does today

**For the HR Manager (a single role; every endpoint needs a login except the health check)**

| Capability | Endpoint |
|---|---|
| Sign in and out (httpOnly cookie session, rate limited) | `POST/GET/DELETE /api/session` |
| **Employee directory:** text search, filters (country, department, job title, status), sort, server-side pagination | `GET /api/employees` |
| Create and edit employees; deactivate instead of deleting | `POST /api/employees`, `PATCH /api/employees/:id` |
| **Salary changes with history:** amount, optional currency, effective date, reason, who did it | `GET/POST /api/employees/:id/salary_changes` |
| **Insights:** headcount and payroll, pay range (min / P25 / median / P75 / max) by country, department or job title, salary distribution, highest and lowest paid | `GET /api/insights/overview`, `salary_stats`, `distribution`, `top_earners` |
| **Outliers:** people paid far outside their peers (same job title, same country) | `GET /api/insights/outliers` |
| **CSV export** of the directory with whatever filters are applied | `GET /api/employees/export` |
| Reference data for filters and forms | `GET /api/lookups` |

Every figure that compares pay across countries is converted to USD at a static, dated exchange rate. What is
deliberately **not** included (payroll, RBAC, live FX, pay-equity analysis, CSV import, …) and why is in
[docs/requirements.md](docs/requirements.md).

## How it is built

| Layer | Choice |
|---|---|
| Backend | Ruby 3.4, **Rails 8.1** (API-only), PostgreSQL |
| Frontend | **React 19 + TypeScript** (Vite); MUI, TanStack Query and Vitest are planned |
| Tests | Minitest + FactoryBot, 249 tests in about 5 s; Brakeman and RuboCop clean |
| CI | GitHub Actions: backend tests, RuboCop, Brakeman; frontend lint and build |
| Delivery | A single multi-stage Docker image with Rails serving the built React app _(planned)_ |

The work is **test-driven**, and the commit history shows it: each feature is a `test:` commit that fails (red)
followed by a `feat:` commit that makes it pass (green). Statistics are computed in SQL
(`percentile_cont`, `GROUP BY`, CTEs), not in Ruby or the browser. Every interactive endpoint responds in under
60 ms at p95 with 10,000 employees ([measurements](docs/performance.md)). The demo data comes from a
**deterministic seed script**: 10,000 employees, and about 10,000 salary changes of history.

## Documentation

| Document | What is in it |
|---|---|
| [docs/requirements.md](docs/requirements.md) | One-page requirements: goal, scope, what is left out and why |
| [docs/implementation-plan.md](docs/implementation-plan.md) | Architecture, data model, API, TDD strategy, delivery plan and its status, and §17 what changed while building |
| [docs/performance.md](docs/performance.md) | Measurements against 10,000 employees, `EXPLAIN` plans, and what was deliberately not optimised |
| `docs/ai-usage.md` | _Planned:_ how AI was used, with key prompts and decisions |

## Getting started

**Requirements:** Ruby 3.4 (the version in `backend/.ruby-version`; with rbenv, `rbenv install 3.4.6`) and Bundler,
Node 20+, and PostgreSQL 16 with a local role that can create databases.

```bash
cd backend
bundle install
bin/rails db:create db:migrate
bin/rails db:seed        # 10,000 employees + salary history + the HR login, about 4 s
bin/rails server         # http://localhost:3000
```

`db:seed` is safe to run again (it adds nothing the second time). `SEED_EMPLOYEES=500 bin/rails db:seed` seeds fewer.
In development it creates the login **`hr@acme.example` / `salary-manager-demo`**; elsewhere set `HR_EMAIL` and
`HR_PASSWORD`.

### Try the API

```bash
# sign in (the session cookie is kept in cookies.txt)
curl -c cookies.txt -H 'Content-Type: application/json' \
     -d '{"email":"hr@acme.example","password":"salary-manager-demo"}' http://localhost:3000/api/session

# the ten best-paid people in Canada, by USD value
curl -b cookies.txt 'http://localhost:3000/api/employees?country_id=6&sort=salary&direction=desc&per_page=10'

# how pay is spread in each country
curl -b cookies.txt 'http://localhost:3000/api/insights/salary_stats?group_by=country'

# who is paid far outside their peers
curl -b cookies.txt 'http://localhost:3000/api/insights/outliers?limit=10'

# the filtered directory as a spreadsheet
curl -b cookies.txt -o employees.csv 'http://localhost:3000/api/employees/export?status=active'
```

The frontend, for now, only shows whether it can reach the API:

```bash
cd frontend && npm install && npm run dev      # http://localhost:5173, proxies /api to Rails
```

## Running the tests

```bash
cd backend
bin/rails test          # 249 tests
bin/rubocop             # style
bin/brakeman            # security scan
ruby script/benchmark.rb  # times every endpoint against a running server (see docs/performance.md)

cd ../frontend
npm run lint && npm run build
```

## Repository layout

```
backend/     Rails 8.1 API: app/ (controllers, models, queries, services, serializers), db/, test/, script/
frontend/    React + TypeScript app (src/)
docs/        Requirements, implementation plan, performance notes
.github/     CI workflow and Dependabot config
```

## Roadmap

Delivery is a sequence of small, tested, committed slices; see §11 of the
[implementation plan](docs/implementation-plan.md#11-delivery-plan-incremental-commits).

- [x] Rails API and React scaffold; requirements, plan and README
- [x] Tooling and CI (backend)
- [x] Data model and the 10,000-employee seed, with salary history
- [x] Authentication
- [x] Employees API and salary changes
- [x] Insights API, outliers and CSV export
- [x] Performance measurements
- [ ] Frontend: shell and login, employees, salary changes, insights dashboard
- [ ] Docker image, deployment, demo video
