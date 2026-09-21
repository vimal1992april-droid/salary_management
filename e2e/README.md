# End-to-end tests

A real browser (Chromium, through [Playwright](https://playwright.dev)) driving the whole product, the way the HR
manager would: signing in, finding someone in the directory, adding an employee, changing their salary,
deactivating them, and reading the insights dashboard. It runs against the **production Docker image**, so it also
proves that the image serves the React app, the API and the session cookie from one origin.

The suite in `frontend/` and `backend/` already covers the details with fast tests (jsdom and Minitest); this is one
slow test of the critical path, and it is what found two bugs those suites could not see (a stale validation
message in the forms, and the server caching the app shell).

## Run it

You need Docker. From the repository root:

```bash
docker build -t salary-management:local .                 # the production image (about 2 minutes the first time)

docker network create sm-net
docker run -d --name sm-pg --network sm-net -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=salary_management postgres:17
docker run -d --name sm-app --network sm-net -p 8080:3000 \
  -e DATABASE_URL=postgres://postgres:postgres@sm-pg:5432/salary_management \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -e HR_EMAIL=hr@acme.example -e HR_PASSWORD=e2e-password-123 -e FORCE_SSL=false \
  salary-management:local
# the app migrates and seeds 10,000 employees on its first start; wait for http://localhost:8080/up

cd e2e && npm install
docker run --rm --network sm-net --ipc=host -v "$PWD":/work -w /work \
  -e BASE_URL=http://sm-app:3000 -e HR_EMAIL=hr@acme.example -e HR_PASSWORD=e2e-password-123 \
  mcr.microsoft.com/playwright:v1.63.0-noble bash -c "npm ci && npx playwright test"
```

The Playwright image already contains the browsers, and its tag must match the `@playwright/test` version in
`package.json`. Screenshots of each step are written to `e2e/screenshots/`.

To run against a server on your own machine instead (`bin/rails server` plus `npm run dev`, or the image on
`localhost:8080`), install the browser once with `npx playwright install chromium` and run
`BASE_URL=http://localhost:8080 npx playwright test`.

**Only run it against a throwaway database.** The test adds an employee and changes their salary every time it runs.
