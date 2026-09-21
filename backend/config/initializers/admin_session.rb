# The admin panel is a normal server-rendered part of the app, so it needs a Rails session, which an API-only app
# leaves out. It is a cookie of its own (`_salary_admin`), unrelated to the HR manager's `session_id` cookie, so
# signing in to one never opens the other. The middleware only sets a cookie when a page actually writes to the
# session, so the JSON API is unaffected.
Rails.application.config.middleware.use ActionDispatch::Session::CookieStore,
  key: "_salary_admin",
  httponly: true,
  same_site: :lax,
  secure: Rails.configuration.force_ssl,
  expire_after: 8.hours
