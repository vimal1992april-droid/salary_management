require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  test "is valid with the factory defaults" do
    assert build(:employee).valid?
  end

  %i[employee_number first_name last_name email hire_date salary_amount].each do |attribute|
    test "requires #{attribute}" do
      assert_not build(:employee, attribute => nil).valid?
    end
  end

  test "requires a country, department and job title" do
    assert_not build(:employee, country: nil).valid?
    assert_not build(:employee, department: nil).valid?
    assert_not build(:employee, job_title: nil).valid?
  end

  # --- identity -------------------------------------------------------------

  test "rejects a malformed email" do
    assert_not build(:employee, email: "not-an-email").valid?
  end

  test "normalizes the email by trimming it and lowercasing it" do
    assert_equal "asha.verma@acme.example", build(:employee, email: "  Asha.Verma@ACME.example ").email
  end

  test "requires a unique email, ignoring case" do
    create(:employee, email: "asha@acme.example")

    duplicate = build(:employee, email: "ASHA@acme.example")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "requires a unique employee number" do
    create(:employee, employee_number: "E00042")

    assert_not build(:employee, employee_number: "E00042").valid?
  end

  test "joins first and last name into a full name" do
    assert_equal "Asha Verma", build(:employee, first_name: "Asha", last_name: "Verma").full_name
  end

  # --- salary ---------------------------------------------------------------

  test "requires a salary greater than zero" do
    [ 0, -1 ].each do |amount|
      assert_not build(:employee, salary_amount: amount).valid?, "#{amount} should be rejected"
    end
  end

  test "rejects a salary too large for the column" do
    assert build(:employee, salary_amount: 999_999_999_999.99).valid?
    assert_not build(:employee, salary_amount: 1_000_000_000_000).valid?
  end

  test "converts its salary to USD at the currency's rate, rounded to cents" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    country = create(:country, currency: inr)

    assert_equal BigDecimal("1200.00"), build(:employee, country:, currency: inr, salary_amount: 100_000).salary_usd
    assert_equal BigDecimal("1200.01"), build(:employee, country:, currency: inr, salary_amount: 100_001).salary_usd
  end

  test "the database rejects a non-positive salary even when validations are skipped" do
    employee = create(:employee)
    employee.salary_amount = -5

    assert_raises(ActiveRecord::CheckViolation) { employee.save!(validate: false) }
  end

  # --- hire date ------------------------------------------------------------

  test "cannot have been hired in the future" do
    travel_to Time.zone.local(2026, 6, 15, 12) do
      assert build(:employee, hire_date: Date.new(2026, 6, 15)).valid?
      assert_not build(:employee, hire_date: Date.new(2026, 6, 16)).valid?
    end
  end

  # --- status ---------------------------------------------------------------

  test "is active by default" do
    assert build(:employee).active?
  end

  test "rejects an unknown status" do
    assert_not build(:employee, status: "retired").valid?
  end

  test "the active scope leaves out inactive employees" do
    active = create(:employee)
    create(:employee, status: :inactive)

    assert_equal [ active ], Employee.active.to_a
  end

  # --- currency -------------------------------------------------------------

  test "defaults its currency to the country's currency" do
    country = create(:country)

    employee = build(:employee, country:, currency: nil)
    employee.valid?

    assert_equal country.currency_code, employee.currency_code
  end

  test "keeps an explicitly chosen currency" do
    eur = create(:currency, code: "EUR")

    employee = build(:employee, country: create(:country), currency: eur)
    employee.valid?

    assert_equal "EUR", employee.currency_code
  end

  test "requires a known currency" do
    employee = build(:employee)
    employee.currency_code = "ZZZ"

    assert_not employee.valid?
    assert employee.errors[:currency].any?
  end
end
