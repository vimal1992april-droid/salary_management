require "test_helper"

class Seeding::AdminUserTest < ActiveSupport::TestCase
  test "creates an admin account" do
    user = Seeding::AdminUser.ensure!(email: "admin@acme.example", password: "correct-horse-battery")

    assert_predicate user, :persisted?
    assert_predicate user, :admin?
    assert User.authenticate_by(email: "admin@acme.example", password: "correct-horse-battery")
  end

  test "keeps one account per email when run again, and resets the password" do
    Seeding::AdminUser.ensure!(email: "admin@acme.example", password: "old-password-123")
    Seeding::AdminUser.ensure!(email: "admin@acme.example", password: "new-password-456")

    assert_equal 1, User.count
    assert_nil User.authenticate_by(email: "admin@acme.example", password: "old-password-123")
    assert User.authenticate_by(email: "admin@acme.example", password: "new-password-456")
  end

  test "promotes an existing HR account to admin instead of creating a second one" do
    create(:user, email: "boss@acme.example")

    Seeding::AdminUser.ensure!(email: "boss@acme.example", password: "correct-horse-battery")

    assert_equal 1, User.count
    assert User.find_by!(email: "boss@acme.example").admin?
  end

  test "never makes the HR login an admin" do
    hr = Seeding::HrUser.ensure!(email: "hr@acme.example", password: "correct-horse-battery")

    assert_not hr.admin?
  end
end
