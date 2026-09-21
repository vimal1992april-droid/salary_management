require "test_helper"

class Employees::ChangeSalaryTest < ActiveSupport::TestCase
  setup do
    @hr = create(:user)
    @usd = create(:currency, code: "USD", rate_to_usd: 1)
    @employee = create(:employee, country: create(:country, currency: @usd), salary_amount: 100_000,
                                  hire_date: Date.new(2020, 1, 1))
  end

  def change_salary(**overrides)
    Employees::ChangeSalary.call(
      **{ employee: @employee, new_amount: 110_000, effective_on: Date.new(2024, 4, 1),
          reason: "Annual review", changed_by: @hr }.merge(overrides)
    )
  end

  test "updates the employee's current salary" do
    change_salary

    assert_equal 110_000, @employee.reload.salary_amount
  end

  test "records the previous and new amounts, the date, the reason and who did it" do
    change = change_salary

    assert_predicate change, :persisted?
    assert_equal @employee, change.employee
    assert_equal 100_000, change.previous_amount
    assert_equal 110_000, change.new_amount
    assert_equal [ "USD", "USD" ], [ change.previous_currency_code, change.new_currency_code ]
    assert_equal Date.new(2024, 4, 1), change.effective_on
    assert_equal "Annual review", change.reason
    assert_equal @hr, change.changed_by
  end

  test "can change the currency together with the amount, as on a transfer" do
    gbp = create(:currency, code: "GBP", rate_to_usd: "1.27")

    change = change_salary(new_amount: 80_000, currency_code: "GBP", reason: "Relocated to London")

    assert_equal [ "USD", "GBP" ], [ change.previous_currency_code, change.new_currency_code ]
    assert_equal [ 80_000, "GBP" ], [ @employee.reload.salary_amount, @employee.currency_code ]
    assert_equal gbp, @employee.currency
  end

  test "stacks history: each change starts from the salary the last one set" do
    change_salary(new_amount: 110_000, effective_on: Date.new(2024, 4, 1))
    second = change_salary(new_amount: 125_000, effective_on: Date.new(2025, 4, 1), reason: "Promotion")

    assert_equal 110_000, second.previous_amount
    assert_equal 2, @employee.salary_changes.count
  end

  test "accepts amounts given as text, as they arrive from a request" do
    change_salary(new_amount: "115000.50")

    assert_equal BigDecimal("115000.50"), @employee.reload.salary_amount
  end

  test "rejects a change that leaves the salary as it was, and saves nothing" do
    assert_no_difference -> { SalaryChange.count } do
      assert_raises(ActiveRecord::RecordInvalid) { change_salary(new_amount: 100_000) }
    end
  end

  test "rejects a non-positive or non-numeric amount" do
    [ 0, -5, "abc" ].each do |amount|
      assert_raises(ActiveRecord::RecordInvalid, "#{amount.inspect} should be rejected") { change_salary(new_amount: amount) }
    end
    assert_equal 100_000, @employee.reload.salary_amount
  end

  test "requires a reason and an effective date" do
    assert_raises(ActiveRecord::RecordInvalid) { change_salary(reason: "") }
    assert_raises(ActiveRecord::RecordInvalid) { change_salary(effective_on: nil) }
  end

  test "rejects a date in the future or before the hire date" do
    travel_to Time.zone.local(2026, 6, 15, 12) do
      assert_raises(ActiveRecord::RecordInvalid) { change_salary(effective_on: Date.new(2026, 6, 16)) }
      assert_raises(ActiveRecord::RecordInvalid) { change_salary(effective_on: Date.new(2019, 12, 31)) }
    end
  end

  test "rejects an unknown currency" do
    assert_raises(ActiveRecord::RecordInvalid) { change_salary(currency_code: "ZZZ") }
    assert_equal "USD", @employee.reload.currency_code
  end

  test "is all or nothing: if the employee cannot be saved, no history is left behind" do
    @employee.update_column(:email, "not-an-email") # a record that no longer passes validation

    assert_no_difference -> { SalaryChange.count } do
      assert_raises(ActiveRecord::RecordInvalid) { change_salary }
    end
    assert_equal 100_000, @employee.reload.salary_amount
  end
end
