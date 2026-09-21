require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  test "is valid with a name" do
    assert build(:department).valid?
  end

  test "requires a name" do
    assert_not build(:department, name: "").valid?
  end

  test "requires a unique name, ignoring case" do
    create(:department, name: "Engineering")

    assert_not build(:department, name: "engineering").valid?
  end
end
