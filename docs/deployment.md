# Deployment

The product ships as **one Docker image**: Rails serves the API and the built React app from a single origin, so
there is one service to run and no CORS to configure. The image is built from the [Dockerfile](../Dockerfile) at the
repository root, in four stages (build the React app, install the gems, then a slim runtime that runs as a non-root
user), and is about 395 MB.

## Deploying on Render

[render.yaml](../render.yaml) is a blueprint for a web service built from the Dockerfile plus a Postgres database.

1. Push this repository to GitHub.
2. In Render: **New > Blueprint**, choose the repository. Render reads `render.yaml`.
3. When asked, give it the four values marked `sync: false`: `HR_EMAIL` and `HR_PASSWORD` (the HR manager's login) and
   `ADMIN_EMAIL` and `ADMIN_PASSWORD` (the administrator's login for `/admin`).
4. Deploy. The first start migrates the database and seeds the 10,000 demo employees (about 15 seconds); later
   starts find the data and do not seed again.
5. Put the URL, and the login you chose, in the README.

Render provides `DATABASE_URL` and `PORT`; the blueprint generates `SECRET_KEY_BASE`. Check Render's current
free-plan limits (idle spin-down, database retention) before relying on it for a demo, since they change; the first
request after an idle period will be slow while the service wakes and Puma boots.

Any host that runs a container works the same way (Fly.io, Railway, a VPS): set the variables below and expose the
port.

## Environment variables

| Variable | Required | Meaning |
|---|---|---|
| `DATABASE_URL` | yes | PostgreSQL connection string. |
| `SECRET_KEY_BASE` | yes | Signs the session cookie. Generate with `openssl rand -hex 64`. Never committed. |
| `HR_EMAIL`, `HR_PASSWORD` | yes for a login | Create (or reset) the HR manager's login on every start. Without them there is no way to sign in. |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | yes for the admin panel | Create (or reset) the administrator's login on every start; it opens `/admin`, and the HR login does not. Without them the panel exists but nobody can sign in. |
| `API_MONITOR` | no | `false` stops the API monitor recording calls (default on). It stores request and response payloads, which include names, emails and pay; see [admin.md](admin.md). |
| `PORT` | no | Port Puma listens on (default 3000). |
| `FORCE_SSL` | no | Default `true`: the app assumes TLS is terminated by the host's proxy and marks the session cookie `Secure`. Set `false` only to try the image over plain HTTP. |
| `RAILS_MAX_THREADS` | no | Puma threads (default 3). |
| `SEED_EMPLOYEES` | no | How many employees a first-time seed creates (default 10,000). |

## Constraints worth knowing

- **One Puma process.** The login rate limiter keeps its counters in memory. Before running more than one process,
  switch the cache store in `config/environments/production.rb` to a shared one (Redis or Solid Cache).
- **The demo data is synthetic.** No real employee data is used or needed.
- **Secrets stay out of the image and the repository:** `master.key` and env files are git-ignored and listed in
  `.dockerignore`.

## What was verified, and what was not

Verified locally by building the image and running it against a real PostgreSQL 17 container, and by driving it with
a real browser (see [e2e/README.md](../e2e/README.md)):

- it starts on an empty database in about 11 seconds, migrating and seeding 10,000 employees and their history;
  a restart finds the data and does not seed again;
- the pages (`/`, `/employees`, `/insights`) come back as the app shell with `no-cache`, hashed files under
  `/assets/` are cached for a year, and a missing asset or an unknown API path is a plain 404 rather than the app;
- the API works from the same origin: login sets an `httpOnly`, `SameSite=Lax` cookie (also `Secure` with TLS on),
  the API refuses requests without a session, and insights, outliers and the CSV export return the seeded data;
- the administrator's panel, in the same browser run: signing in (and being refused with the HR login), the dashboard,
  the data pages, the API monitor and one call's payload with its password filtered, and signing out;
- four bugs were found this way and fixed (a page returning 404 to clients that send only `Accept: */*`, the app
  shell being cached for a year by the static file server, `bin/start-production` having gained Windows line endings
  so the container exited at once, and the admin's Sign out button doing nothing in a real browser).

**Verified on Render itself, from the `render.yaml` blueprint:** https://salary-management-bnkn.onrender.com is live —
the free-plan Postgres database and web service, built from the Dockerfile exactly as described above, with no
changes needed to the image or the start command. The only surprise was host-specific, not app-specific: the free
plan's idle spin-down, which makes the first request after a quiet period slow while the service wakes and Puma
boots (documented above).
