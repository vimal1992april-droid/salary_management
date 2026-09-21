# Backend

The Rails 8.1 API (Ruby 3.4, PostgreSQL) and the server-rendered administrator's panel at `/admin`. The whole
product, how it is built and how to run it is in the [repository README](../README.md); this page is the short version
for working in this folder.

## Run it

```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed        # 10,000 employees, their salary history and the two demo logins
bin/rails server         # http://localhost:3000
```

Restart the server after pulling new code: it reads its configuration and any new directories only when it starts.

## Signing in

| | Address | Email | Password |
|---|---|---|---|
| HR manager (the React app, run from `../frontend`) | http://localhost:5173 | `hr@acme.example` | `salary-manager-demo` |
| Administrator (this app's `/admin` panel) | http://localhost:3000/admin | `admin@acme.example` | `admin-panel-demo` |

Both are created by `bin/rails db:seed` in development only. Elsewhere set `HR_EMAIL` and `HR_PASSWORD`, and
`ADMIN_EMAIL` and `ADMIN_PASSWORD`; without them there is no login. The two accounts are separate: the HR login cannot
open `/admin`, and the admin login cannot use the HR API. More in the
[README](../README.md#signing-in) and in [docs/admin.md](../docs/admin.md).

## Test it

```bash
bin/rails test && bin/rubocop && bin/brakeman     # 487 tests in about 7 s
```
