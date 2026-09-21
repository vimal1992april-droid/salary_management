require "test_helper"

class Seeding::HrUserTest < ActiveSupport::TestCase
  test "creates the HR manager account" do
    user = Seeding::HrUser.ensure!(email: "hr@acme.example", password: "correct-horse-battery")

    assert_predicate user, :persisted?
    assert User.authenticate_by(email: "hr@acme.example", password: "correct-horse-battery")
  end

  test "keeps one account per email when run again" do
    2.times { Seeding::HrUser.ensure!(email: "hr@acme.example", password: "correct-horse-battery") }

    assert_equal 1, User.count
  end

  test "resets the password when run again with a new one" do
    Seeding::HrUser.ensure!(email: "hr@acme.example", password: "old-password-123")
    Seeding::HrUser.ensure!(email: "hr@acme.example", password: "new-password-456")

    assert_nil User.authenticate_by(email: "hr@acme.example", password: "old-password-123")
    assert User.authenticate_by(email: "hr@acme.example", password: "new-password-456")
  end
end
