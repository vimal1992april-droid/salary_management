require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "belongs to a user" do
    assert_not build(:session, user: nil).valid?
  end

  test "is active for 14 days after it starts" do
    session = create(:session)

    travel 13.days do
      assert_not session.expired?
      assert_includes Session.active, session
    end
  end

  test "expires after 14 days" do
    session = create(:session)

    travel 15.days do
      assert session.expired?
      assert_not_includes Session.active, session
    end
  end
end
