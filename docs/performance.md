# Performance

The requirement is that the directory and insight endpoints respond in under about **300 ms (p95)** with
**10,000 employees**. This note records what was measured, how to repeat it, and which optimisations were
deliberately *not* made because the measurements did not call for them.

## How to repeat the measurements

```bash
cd backend
bin/rails db:seed            # 10,000 employees, ~10,000 salary changes, ~4 s
bin/rails server             # in another terminal
ruby script/benchmark.rb     # RUNS=100 BASE_URL=http://localhost:3000 to change the defaults
```

[backend/script/benchmark.rb](../backend/script/benchmark.rb) is a plain HTTP client. It logs in, discovers ids
from the API, warms each endpoint once, times it 30 times over real HTTP and prints the Markdown table below.
It loads no Rails code, so it can be pointed at a deployment too.

## Results

Measured against the seeded development database: 10,000 employees and 10,053 salary changes, PostgreSQL 16,
Ruby 3.4.6, Rails 8.1, a **development-mode server on a laptop under WSL2**. Development mode reloads code between
requests, so production should be equal or better.

| Endpoint | p50 (ms) | p95 (ms) | max (ms) | Response |
|---|---:|---:|---:|---:|
| Directory, first page | 16 | 29 | 30 | 10 KB |
| Directory, text search ("priya") | 46 | 52 | 52 | 10 KB |
| Directory, two-word search ("priya nair") | 46 | 59 | 90 | 4 KB |
| Directory, filters + sort by hire date | 15 | 20 | 22 | 10 KB |
| Directory, sort by salary (USD), 100 per page | 27 | 34 | 38 | 40 KB |
| Directory, sort by country name, 100 per page | 22 | 27 | 27 | 40 KB |
| Directory, last page | 26 | 43 | 46 | 10 KB |
| Lookups | 9 | 12 | 13 | 3 KB |
| Insights, overview | 17 | 18 | 18 | 0 KB |
| Insights, pay stats by country | 19 | 23 | 25 | 1 KB |
| Insights, pay stats by department | 19 | 25 | 26 | 1 KB |
| Insights, pay stats by job title | 20 | 23 | 23 | 5 KB |
| Insights, distribution (12 buckets) | 23 | 30 | 36 | 1 KB |
| Insights, top earners | 18 | 30 | 31 | 4 KB |
| Insights, outliers | 29 | 31 | 32 | 14 KB |
| CSV export, all employees | 633 | 743 | 754 | 1.3 MB |
| Salary history of one employee | 11 | 15 | 16 | 1 KB |

**Every interactive endpoint is under 60 ms at p95, about five times inside the target.** The one exception is the
CSV export: it is a 1.3 MB file download of all 10,000 rows rather than an interactive request, so the 300 ms
target does not apply, and 0.7 s is acceptable for a file the user asks for explicitly.

Other timings: seeding 10,000 employees takes about 3 s and adding their salary history about 1.5 s more; the backend
test suite (249 tests) runs in about 4 s.

## What makes it fast

- **Aggregation happens in PostgreSQL.** Percentiles, sums, histograms and outlier fences are one SQL statement
  each (`percentile_cont`, `GROUP BY`, a CTE), so the API returns a few rows however many employees there are.
  The browser never receives 10,000 rows, and Ruby never loops over them.
- **Pagination is server side** and capped at 100 rows per page.
- **No N+1 queries.** Every list preloads its associations, and tests assert that a page of 2 and a page of 12
  employees run the same number of SQL statements (`count_queries` in the test helper).
- **Foreign key indexes** on `employees` (country, department, job title) exist because Rails creates them with
  `references`; unique indexes back the natural keys.

## What was measured and left alone

`EXPLAIN ANALYZE` on the queries the directory and insights actually run, over 10,000 rows (the `employees`
table plus its indexes is 3 MB, so it lives entirely in memory):

| Query | Plan | Execution time |
|---|---|---:|
| Text search, `ILIKE` on four columns | sequential scan, top-N heapsort | 17 ms |
| First page ordered by name | sequential scan, top-N heapsort | 2.4 ms |
| Filters + order by hire date | bitmap index scan on `country_id`, top-N heapsort | ~1 ms |
| Sort by USD salary (join currencies) | hash join, top-N heapsort | ~15 ms |
| Pay stats by country | hash joins, sort, group aggregate | ~20 ms |

- **No trigram (`pg_trgm`) index for search.** A sequential scan of 10,000 rows for a four-column `ILIKE` costs
  17 ms, so an index would save little and add a Postgres extension to manage. It becomes worthwhile at roughly a
  hundred times the data (about a million rows). At that point the change is one migration: a GIN trigram index on the
  concatenated searchable columns.
- **No index on `status` or on `(country_id, salary_amount)`.** The planner already uses the `country_id` index where
  it helps, and sorting a few thousand rows in memory is cheap.
- **No caching, background jobs or materialised views.** Nothing measured needs them, and each would add a way for
  the numbers to be stale, which matters more for pay data than saving 20 ms.
- **The USD value is computed on the fly** (`salary_amount x currencies.rate_to_usd`) rather than stored. Storing it
  would speed sorting slightly but would go stale whenever a rate changed.

## If the data grew

At about 100x (a million employees) the first things to revisit, in order: a trigram index for search; an index or
materialised summary for the insights (with a defined refresh rule); keyset instead of offset pagination for deep pages;
and streaming the CSV export instead of building it in memory. None of that is needed at 10,000.
