module Seeding
  # Decides which logins exist. Used by db:seed and by the production start script, so the rules live in one place.
  #
  # A login is created from an EMAIL and PASSWORD pair of environment variables; both must be set. Local development
  # alone falls back to documented demo logins. Passwords are never included in what is reported.
  module Logins
    DEVELOPMENT_HR = { email: "hr@acme.example", password: "salary-manager-demo" }.freeze
    DEVELOPMENT_ADMIN = { email: "admin@acme.example", password: "admin-panel-demo" }.freeze

    module_function

    # Returns the messages to show the person running it, one per login.
    def ensure_from_env!(env = ENV, development: Rails.env.development?)
      [
        ensure_login("HR", env, development ? DEVELOPMENT_HR : nil) { |email, password| HrUser.ensure!(email: email, password: password) },
        ensure_login("admin", env, development ? DEVELOPMENT_ADMIN : nil) { |email, password| AdminUser.ensure!(email: email, password: password) }
      ]
    end

    def ensure_login(label, env, fallback)
      prefix = label.upcase
      email = env["#{prefix}_EMAIL"].presence
      password = env["#{prefix}_PASSWORD"].presence
      email, password = fallback&.values_at(:email, :password) unless email && password

      return "#{prefix}_EMAIL and #{prefix}_PASSWORD are not both set: no #{label} login was created." unless email && password

      yield email, password
      "#{label.upcase_first} login ready: #{email}"
    end
    private_class_method :ensure_login
  end
end
