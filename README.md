# Salary Management

Web-based salary management for an organisation with **10,000 employees across multiple countries**.
It replaces the HR team's Excel files. The HR Manager can find and maintain salary data and answer
questions about **how the organisation pays its people**.

> **Status: planning complete, building starts next.** The repo currently contains the documentation
> and a working Rails + React scaffold (the frontend calls a health endpoint on the API). The
> features below are the plan, not yet built. This README is updated as each one lands.

- **Live demo:** _not deployed yet_
- **Demo video:** _not recorded yet_

## What it will do

**For the HR Manager (single role, login required)**

- **Employee directory:** search, filter (country, department, job title, status), sort and page through 10,000 people quickly.
- **Maintain records:** create and edit employees; deactivate instead of deleting, so history is kept.
- **Salary changes with history:** every change records the previous and new amount, effective date and reason.
- **Insights dashboard:** headcount, total payroll, and min / P25 / median / P75 / max pay by country, department and job title; salary distribution; highest and lowest earners.
- **Nice to have:** outlier detection within peer groups; CSV export.

What is deliberately **not** included (payroll, RBAC, live FX, pay-equity analysis, CSV import, …) and why
is in [docs/requirements.md](docs/requirements.md).

## How it is built

| Layer | Choice |
|---|---|
| Backend | Ruby 3.2, **Rails 8** (API-only), PostgreSQL |
| Frontend | **React 19 + TypeScript** (Vite), MUI + DataGrid, TanStack Query |
| Tests | Minitest + FactoryBot (backend); Vitest + React Testing Library + MSW (frontend) |
| Delivery | GitHub Actions CI; single multi-stage Docker image (Rails serves the built React app) |

The work is **test-driven**: each behaviour starts as a failing test, and the commit history shows that
progression. Statistics are computed in SQL (`percentile_cont`), not in Ruby or the browser, and the demo data
comes from a **deterministic seed script** that creates exactly 10,000 employees.

Full design, data model, API, test strategy and the milestone-by-milestone commit plan:
**[docs/implementation-plan.md](docs/implementation-plan.md)**.

## Documentation

| Document | What is in it |
|---|---|
| [docs/requirements.md](docs/requirements.md) | One-page requirements: goal, scope, what is left out and why |
| [docs/implementation-plan.md](docs/implementation-plan.md) | Architecture, data model, API, TDD strategy, delivery plan, risks |
| `docs/ai-usage.md` | _Planned:_ how AI was used, with key prompts and decisions |
| `docs/performance.md` | _Planned:_ measurements against 10,000 employees |

## Getting started (development)

**Requirements:** Ruby 3.2+ and Bundler, Node 20+, PostgreSQL 16 (your local role must be able to create databases).

```bash
# one-time setup
cd backend
bundle install
bin/rails db:create db:migrate

cd ../frontend
npm install
```

```bash
# run (two terminals)
cd backend  && bin/rails server     # API      http://localhost:3000
cd frontend && npm run dev          # web app  http://localhost:5173
```

In development the Vite server proxies `/api/*` to Rails, so the browser talks to one origin.

## Running the tests

```bash
cd backend  && bin/rails test                      # backend suite
cd frontend && npm run lint && npm run build       # lint + type-check + build
```

The frontend unit-test runner (Vitest) is added in milestone 1 of the plan, at which point
`npm test` joins the commands above.

## Repository layout

```
backend/     Rails 8 API (app/, db/, test/)
frontend/    React + TypeScript app (src/)
docs/        Requirements, implementation plan, and later AI-usage and performance notes
```

## Roadmap

Delivery is a sequence of small, tested, committed slices; see §11 of the
[implementation plan](docs/implementation-plan.md#11-delivery-plan-incremental-commits).

- [x] Scaffold Rails API and React app; API health check wired end to end
- [x] Requirements, implementation plan, README
- [ ] Tooling and CI
- [ ] Data model and 10,000-employee seed
- [ ] Authentication
- [ ] Employees API, then salary changes
- [ ] Insights API
- [ ] Frontend: shell, employees, salary changes, insights dashboard
- [ ] Outliers and CSV export
- [ ] Deployment, performance notes, demo video
