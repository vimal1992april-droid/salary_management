require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with an email and a password" do
    assert build(:user).valid?
  end

  test "requires an email" do
    assert_not build(:user, email: "").valid?
  end

  test "rejects a malformed email" do
    assert_not build(:user, email: "not-an-email").valid?
  end

  test "normalizes the email by trimming it and lowercasing it" do
    assert_equal "hr@acme.example", build(:user, email: "  HR@Acme.Example ").email
  end

  test "requires a unique email, ignoring case" do
    create(:user, email: "hr@acme.example")

    assert_not build(:user, email: "HR@acme.example").valid?
  end

  test "requires a password of at least 8 characters when it is created" do
    assert_not build(:user, password: "short").valid?
    assert build(:user, password: "long-enough").valid?
  end

  test "stores only a digest of the password" do
    user = create(:user, password: "correct-horse-battery")

    assert_not_equal "correct-horse-battery", user.password_digest
    assert user.authenticate("correct-horse-battery")
  end

  test "is found by authenticate_by only with the right password" do
    user = create(:user, email: "hr@acme.example", password: "correct-horse-battery")

    assert_equal user, User.authenticate_by(email: "hr@acme.example", password: "correct-horse-battery")
    assert_nil User.authenticate_by(email: "hr@acme.example", password: "wrong-password")
    assert_nil User.authenticate_by(email: "nobody@acme.example", password: "correct-horse-battery")
  end
end
