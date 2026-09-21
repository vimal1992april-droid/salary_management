require "test_helper"

class JobTitleTest < ActiveSupport::TestCase
  test "is valid with a name and level" do
    assert build(:job_title).valid?
  end

  test "requires a name" do
    assert_not build(:job_title, name: "").valid?
  end

  test "requires a unique name, ignoring case" do
    create(:job_title, name: "Software Engineer")

    assert_not build(:job_title, name: "software engineer").valid?
  end

  test "requires a whole-number level of at least 1" do
    [ nil, 0, -1, 1.5 ].each do |level|
      assert_not build(:job_title, level:).valid?, "#{level.inspect} should be rejected"
    end
  end
end
