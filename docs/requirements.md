# Requirements: Salary Management for ACME

## Goal

Replace the Excel files ACME's HR team uses to manage salaries for **10,000 employees across
multiple countries** with a web application. The HR Manager can find and maintain salary data
quickly, and can answer questions about **how the organisation pays its people**.

**Persona:** the HR Manager, a single trusted, non-technical user who works with salary data daily.

## The questions the software must answer

1. How many people do we employ, where, and what is our total annual payroll?
2. What is the pay range (min, P25, median, P75, max) for a job title, department or country?
3. Who are the highest and lowest paid, and who is an outlier against peers in the same role and country?
4. How has one person's salary changed over time, and why?
5. How do I find one person among 10,000, and change their salary safely?

## Scope

| Priority | Feature | Why |
|---|---|---|
| Must | **Login** (single HR role) | Salary data is sensitive; nothing is visible unauthenticated. |
| Must | **Employee directory**: server-side search, filter (country, department, job title, status), sort, pagination | Replaces scrolling through a spreadsheet; must stay fast at 10k rows. |
| Must | **Create / edit employees**; deactivate instead of delete | Keeps history intact and keeps former staff out of pay statistics. |
| Must | **Salary changes with history** (effective date, reason, previous → new value) | Answers question 4; gives an audit trail for the most sensitive edit. |
| Must | **Insights dashboard**: headcount, total payroll, pay statistics by country / department / job title, salary distribution, top/bottom earners | Answers questions 1–3, the core of "how we pay people". |
| Must | **Seed script** producing 10,000 realistic employees, deterministically | Required by the brief; also what makes the insights meaningful in a demo. |
| Should | **Outlier detection** within job title + country peer groups | Turns the dashboard from descriptive into actionable. |
| Should | **CSV export** of the current filtered directory | HR still shares data in spreadsheets; export costs little. |

## Deliberately left out (and why)

| Left out | Reasoning |
|---|---|
| Payroll processing, payslips, tax, benefits, bonuses, equity | A different product. This tool records and analyses **base salary**, not the pay run. |
| Multiple roles / RBAC, SSO, MFA, password reset | The brief has one persona. One authenticated role is enough; real RBAC is designed only when a second role exists. |
| Live FX rates | Cross-country comparison needs *a* consistent rate, not the *current* one. Static, dated rates in a table are deterministic and testable. |
| Gender / demographic pay-equity analysis | Valuable, but it needs sensitive personal data and legal review. It is the first follow-up, not a corner to cut quietly. |
| Salary bands, approval workflows, notifications | Process features for a team larger than one HR manager. |
| CSV **import** | The seed script stands in for the initial load. A real migration would need a validation and error-reporting UX that deserves its own design. |
| Full audit log of every field change | Salary history covers the most sensitive change. A generic audit trail is over-scoped here. |
| Caching, background jobs, search engine | 10,000 rows is small. Indexed SQL is fast enough; measure before adding infrastructure. |

## Assumptions

- "Salary" means **annual gross base salary**, stored in the employee's local currency.
- Each country has one currency. Cross-country statistics are converted to USD with static, dated rates.
- Insights include **active** employees only.
- One organisation (no multi-tenancy). Roughly 10,000 employees, a few concurrent users.

## Non-functional requirements

- **Performance:** directory and insight endpoints respond in under ~300 ms (p95) with 10,000 employees.
- **Quality:** test-driven; fast, deterministic tests. Backend suite under ~30 s, frontend under ~15 s.
- **Security:** authenticated access, hashed passwords, no secrets in the repository, HTTPS when deployed.
- **Readiness:** deployed and publicly reachable, with a seeded demo account and a short demo video.

## How we will know it works

The HR Manager can log in, answer questions 1–3 from the dashboard in under a minute, find any
employee in a few seconds, and change a salary with the change appearing in that person's history.
