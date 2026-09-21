require "test_helper"

class Seeding::SalaryHistoryTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 9, 21, 12)
    Seeding::Runner.call(employees: 300, history: false)
  end

  def load_history(**options)
    Seeding::SalaryHistory.new(**options).load!
  end

  def history_of(employee)
    employee.salary_changes.order(:effective_on, :id).to_a
  end

  test "creates salary history for a good share of the employees" do
    created = load_history

    assert_operator created, :>, 100
    assert_equal created, SalaryChange.count
    assert_operator SalaryChange.distinct.count(:employee_id), :>, 60
  end

  test "gives no history to someone hired less than a year before the seed's reference date" do
    recent = Employee.where("hire_date > ?", Seeding::Catalog::REFERENCE_DATE - 365)

    load_history

    assert_predicate recent, :any?
    assert_empty SalaryChange.where(employee: recent)
  end

  test "each history ends at the employee's current salary and chains from one change to the next" do
    load_history

    Employee.joins(:salary_changes).distinct.find_each do |employee|
      changes = history_of(employee)

      assert_equal employee.salary_amount, changes.last.new_amount, "#{employee.employee_number} does not end at the current salary"
      changes.each_cons(2) do |earlier, later|
        assert_equal earlier.new_amount, later.previous_amount, "#{employee.employee_number} has a gap in its history"
      end
    end
  end

  test "every change is a raise, in the employee's own currency" do
    load_history

    SalaryChange.includes(:employee).find_each do |change|
      assert_operator change.new_amount, :>, change.previous_amount
      assert_equal change.employee.currency_code, change.previous_currency_code
      assert_equal change.employee.currency_code, change.new_currency_code
    end
  end

  test "changes fall between the hire date and the reference date, in order" do
    load_history

    Employee.joins(:salary_changes).distinct.find_each do |employee|
      dates = history_of(employee).map(&:effective_on)

      assert_operator dates.first, :>=, employee.hire_date
      assert_operator dates.last, :<=, Seeding::Catalog::REFERENCE_DATE
      assert_equal dates.sort, dates
      assert_equal dates.uniq, dates
    end
  end

  test "produces records that pass the model validations" do
    load_history

    invalid = SalaryChange.find_each.reject(&:valid?)

    assert_empty invalid.map { |change| [ change.id, change.errors.full_messages ] }
  end

  test "is seeded history: attributed to nobody and carrying a reason" do
    load_history

    assert_empty SalaryChange.where.not(changed_by_id: nil)
    assert_empty SalaryChange.where(reason: [ nil, "" ])
    assert_operator SalaryChange.distinct.count(:reason), :>, 1
  end

  test "is deterministic: the same seed produces identical history" do
    load_history(seed: 5)
    first_run = snapshot
    SalaryChange.delete_all

    load_history(seed: 5)

    assert_equal first_run, snapshot
  end

  test "a different seed produces different history" do
    load_history(seed: 5)
    first_run = snapshot
    SalaryChange.delete_all

    load_history(seed: 6)

    assert_not_equal first_run, snapshot
  end

  test "is idempotent: running again adds nothing" do
    load_history
    count = SalaryChange.count

    assert_equal 0, load_history
    assert_equal count, SalaryChange.count
  end

  test "the runner seeds history by default and reports it" do
    SalaryChange.delete_all
    Employee.delete_all

    result = Seeding::Runner.call(employees: 200)

    assert_operator result.salary_changes_created, :>, 0
    assert_equal result.salary_changes_created, SalaryChange.count
  end

  test "the runner can leave history out" do
    SalaryChange.delete_all

    result = Seeding::Runner.call(employees: 300, history: false)

    assert_equal 0, result.salary_changes_created
    assert_equal 0, SalaryChange.count
  end

  private

  def snapshot
    SalaryChange.joins(:employee).order("employees.employee_number", :effective_on)
                .pluck("employees.employee_number", :effective_on, :previous_amount, :new_amount, :reason)
  end
end
