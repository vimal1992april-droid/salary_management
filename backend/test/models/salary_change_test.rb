require "test_helper"

class SalaryChangeTest < ActiveSupport::TestCase
  test "is valid with the factory defaults" do
    assert build(:salary_change).valid?
  end

  test "requires an employee" do
    assert_not build(:salary_change, employee: nil).valid?
  end

  test "records who made it, but a change without a user (imported history) is allowed" do
    assert build(:salary_change, changed_by: nil).valid?
  end

  test "requires a reason of at most 500 characters" do
    assert_not build(:salary_change, reason: "").valid?
    assert_not build(:salary_change, reason: "x" * 501).valid?
    assert build(:salary_change, reason: "x" * 500).valid?
  end

  test "requires an effective date" do
    assert_not build(:salary_change, effective_on: nil).valid?
  end

  test "requires positive amounts small enough for the column" do
    [ 0, -1, 1_000_000_000_000 ].each do |amount|
      assert_not build(:salary_change, new_amount: amount).valid?, "new #{amount} should be rejected"
      assert_not build(:salary_change, previous_amount: amount).valid?, "previous #{amount} should be rejected"
    end
  end

  test "requires known currencies" do
    assert_not build(:salary_change, new_currency_code: "ZZZ").valid?
    assert_not build(:salary_change, previous_currency_code: "ZZZ").valid?
  end

  test "must actually change the salary" do
    employee = create(:employee)
    same = build(:salary_change, employee:, previous_amount: 50_000, new_amount: 50_000,
                                 previous_currency_code: employee.currency_code, new_currency_code: employee.currency_code)

    assert_not same.valid?
    assert_includes same.errors[:new_amount], "must differ from the current salary"
  end

  test "the same amount in a different currency is a change" do
    employee = create(:employee)
    other = create(:currency, code: "EUR")

    assert build(:salary_change, employee:, previous_amount: 50_000, new_amount: 50_000,
                                 previous_currency_code: employee.currency_code, new_currency_code: other.code).valid?
  end

  test "cannot take effect in the future" do
    travel_to Time.zone.local(2026, 6, 15, 12) do
      assert build(:salary_change, effective_on: Date.new(2026, 6, 15)).valid?
      assert_not build(:salary_change, effective_on: Date.new(2026, 6, 16)).valid?
    end
  end

  test "cannot take effect before the employee was hired" do
    employee = create(:employee, hire_date: Date.new(2023, 5, 1))

    assert_not build(:salary_change, employee:, effective_on: Date.new(2023, 4, 30)).valid?
    assert build(:salary_change, employee:, effective_on: Date.new(2023, 5, 1)).valid?
  end

  test "newest_first orders by effective date, then by id" do
    employee = create(:employee)
    older = create(:salary_change, employee:, effective_on: Date.new(2023, 1, 1))
    newer = create(:salary_change, employee:, effective_on: Date.new(2024, 1, 1))
    same_day_later = create(:salary_change, employee:, effective_on: Date.new(2024, 1, 1))

    assert_equal [ same_day_later, newer, older ], employee.salary_changes.newest_first.to_a
  end

  test "the database rejects a non-positive amount even when validations are skipped" do
    change = create(:salary_change)
    change.new_amount = -5

    assert_raises(ActiveRecord::CheckViolation) { change.save!(validate: false) }
  end
end
