require "test_helper"

class Seeding::RunnerTest < ActiveSupport::TestCase
  SNAPSHOT_COLUMNS = %i[
    employee_number first_name last_name email hire_date status salary_amount currency_code
    country_id department_id job_title_id
  ].freeze

  setup { travel_to Time.zone.local(2026, 9, 21, 12) }

  test "creates exactly the requested number of employees" do
    Seeding::Runner.call(employees: 120)

    assert_equal 120, Employee.count
  end

  test "numbers employees E00001 upwards" do
    Seeding::Runner.call(employees: 12)

    assert_equal (1..12).map { |n| format("E%05d", n) }, Employee.order(:employee_number).pluck(:employee_number)
  end

  test "reports how many employees it created, and none when run again" do
    assert_equal 120, Seeding::Runner.call(employees: 120).employees_created
    assert_equal 0, Seeding::Runner.call(employees: 120).employees_created
  end

  test "is idempotent" do
    2.times { Seeding::Runner.call(employees: 120) }

    assert_equal 120, Employee.count
  end

  test "handles a batch size that does not divide the employee count" do
    Seeding::Runner.call(employees: 120, batch_size: 50)

    assert_equal 120, Employee.count
  end

  test "is deterministic: the same seed produces identical data" do
    Seeding::Runner.call(employees: 80, seed: 7)
    first_run = snapshot
    SalaryChange.delete_all # history references employees
    Employee.delete_all

    Seeding::Runner.call(employees: 80, seed: 7)

    assert_equal first_run, snapshot
  end

  test "a different seed produces different data" do
    Seeding::Runner.call(employees: 80, seed: 7)
    first_run = snapshot
    SalaryChange.delete_all # history references employees
    Employee.delete_all

    Seeding::Runner.call(employees: 80, seed: 8)

    assert_not_equal first_run, snapshot
  end

  test "generates records that pass the model validations" do
    Seeding::Runner.call(employees: 100)

    invalid = Employee.find_each.reject(&:valid?)

    assert_empty invalid.map { |employee| [ employee.employee_number, employee.errors.full_messages ] }
  end

  test "pays every employee in the currency of their country" do
    Seeding::Runner.call(employees: 200)

    mismatched = Employee.joins(:country).where("employees.currency_code <> countries.currency_code")

    assert_empty mismatched
  end

  test "gives every employee a positive salary and a hire date in the past" do
    Seeding::Runner.call(employees: 200)

    assert Employee.all.all? { |employee| employee.salary_amount.positive? }
    assert_operator Employee.maximum(:hire_date), :<=, Date.current
  end

  test "spreads employees over every country and department" do
    Seeding::Runner.call(employees: 1_000)

    assert_equal Country.count, Employee.distinct.count(:country_id)
    assert_equal Department.count, Employee.distinct.count(:department_id)
  end

  test "leaves a minority of employees inactive" do
    Seeding::Runner.call(employees: 1_000)

    inactive = Employee.inactive.count

    assert_operator inactive, :>, 0
    assert_operator inactive, :<, 150
  end

  test "pays more senior titles more than junior ones in the same country" do
    Seeding::Runner.call(employees: 2_000)
    india = Country.find_by!(iso_code: "IN")

    average = ->(title_name) { Employee.joins(:job_title).where(country: india, job_titles: { name: title_name }).average(:salary_amount) }

    assert_operator average.call("Staff Engineer"), :>, average.call("Software Engineer I")
  end

  private

  def snapshot
    Employee.order(:employee_number).pluck(*SNAPSHOT_COLUMNS)
  end
end
