require "test_helper"

class Seeding::LoginsTest < ActiveSupport::TestCase
  ENV_LOGINS = {
    "HR_EMAIL" => "hr@example.com", "HR_PASSWORD" => "hr-password-123",
    "ADMIN_EMAIL" => "admin@example.com", "ADMIN_PASSWORD" => "admin-password-123"
  }.freeze

  test "creates the HR login and the admin login from the environment" do
    Seeding::Logins.ensure_from_env!(ENV_LOGINS)

    hr = User.authenticate_by(email: "hr@example.com", password: "hr-password-123")
    admin = User.authenticate_by(email: "admin@example.com", password: "admin-password-123")
    assert_not hr.admin?
    assert admin.admin?
  end

  test "reports what it did, never including a password" do
    messages = Seeding::Logins.ensure_from_env!(ENV_LOGINS)

    assert_equal [ "HR login ready: hr@example.com", "Admin login ready: admin@example.com" ], messages
  end

  test "skips a login unless both its variables are set" do
    messages = Seeding::Logins.ensure_from_env!({ "HR_EMAIL" => "hr@example.com", "ADMIN_PASSWORD" => "admin-password-123" })

    assert_equal 0, User.count
    assert_equal [ "HR_EMAIL and HR_PASSWORD are not both set: no HR login was created.",
                   "ADMIN_EMAIL and ADMIN_PASSWORD are not both set: no admin login was created." ], messages
  end

  test "is idempotent" do
    2.times { Seeding::Logins.ensure_from_env!(ENV_LOGINS) }

    assert_equal 2, User.count
  end

  test "gives local development documented demo logins, and nowhere else" do
    Seeding::Logins.ensure_from_env!({}, development: true)

    assert User.authenticate_by(email: "hr@acme.example", password: "salary-manager-demo")
    assert User.authenticate_by(email: "admin@acme.example", password: "admin-panel-demo").admin?
    User.delete_all

    Seeding::Logins.ensure_from_env!({}, development: false)

    assert_equal 0, User.count
  end

  test "an environment value beats the development demo login" do
    Seeding::Logins.ensure_from_env!({ "ADMIN_EMAIL" => "me@example.com", "ADMIN_PASSWORD" => "my-password-123" }, development: true)

    assert User.authenticate_by(email: "me@example.com", password: "my-password-123").admin?
    assert_nil User.find_by(email: "admin@acme.example")
  end
end
