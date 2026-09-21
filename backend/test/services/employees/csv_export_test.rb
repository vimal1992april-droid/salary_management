require "test_helper"
require "csv"

class Employees::CsvExportTest < ActiveSupport::TestCase
  def export(employees)
    Employees::CsvExport.call(employees)
  end

  def parse(csv)
    CSV.parse(csv.delete_prefix("﻿"), headers: true)
  end

  test "starts with a byte order mark so Excel reads it as UTF-8" do
    assert export([]).start_with?("﻿")
  end

  test "has a header row of readable column names" do
    assert_equal [ "Employee number", "First name", "Last name", "Email", "Country", "Department", "Job title",
                   "Hire date", "Status", "Salary", "Currency", "Salary (USD)" ],
                 parse(export([])).headers
  end

  test "an empty list is just the header" do
    assert_equal 0, parse(export([])).size
  end

  test "writes one row per employee with plain, unformatted numbers" do
    usd = create(:currency, code: "USD", rate_to_usd: 1)
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    employee = create(:employee, employee_number: "E00001", first_name: "Asha", last_name: "Verma",
                                 email: "asha@acme.example", hire_date: Date.new(2022, 3, 1), salary_amount: 5_000_000,
                                 country: create(:country, name: "India", currency: inr),
                                 department: create(:department, name: "Engineering"),
                                 job_title: create(:job_title, name: "Engineer"))
    # An explicit number: the factory's own sequence could hand out E00001 too, depending on which tests ran first.
    create(:employee, employee_number: "E99999", country: create(:country, currency: usd), salary_amount: 100)

    row = parse(export(Employee.where(id: employee.id).preload(:country, :department, :job_title, :currency))).first

    assert_equal [ "E00001", "Asha", "Verma", "asha@acme.example", "India", "Engineering", "Engineer",
                   "2022-03-01", "active", "5000000.0", "INR", "60000.0" ],
                 row.fields
  end

  test "quotes commas, quotes and line breaks so the columns stay aligned" do
    tricky = create(:employee, first_name: "Asha, \"the boss\"", last_name: "Line\nBreak")

    rows = parse(export([ tricky ]))

    assert_equal 1, rows.size
    assert_equal "Asha, \"the boss\"", rows.first["First name"]
    assert_equal "Line\nBreak", rows.first["Last name"]
  end

  test "neutralises spreadsheet formulas in text fields" do
    [ "=HYPERLINK(\"http://evil\")", "+1+1", "-2+3", "@SUM(A1)", "\tTAB", "\rCR" ].each do |payload|
      employee = create(:employee, first_name: payload)

      value = parse(export([ employee ])).first["First name"]

      assert value.start_with?("'"), "#{payload.inspect} should be prefixed, got #{value.inspect}"
    end
  end

  test "leaves ordinary text alone" do
    employee = create(:employee, first_name: "Asha-Rose", last_name: "O'Neil")

    row = parse(export([ employee ])).first

    assert_equal [ "Asha-Rose", "O'Neil" ], [ row["First name"], row["Last name"] ]
  end
end
