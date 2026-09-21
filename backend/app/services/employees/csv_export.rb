require "csv"

module Employees
  # Renders employees as CSV for a spreadsheet: UTF-8 with a byte order mark (so Excel reads non-ASCII
  # names correctly), readable headers, and plain unformatted numbers.
  #
  # Names and emails are user-controlled, so text that a spreadsheet would run as a formula (starting
  # with = + - @ tab or CR) is prefixed with an apostrophe to make it inert.
  class CsvExport
    BYTE_ORDER_MARK = "﻿".freeze
    FORMULA_TRIGGERS = [ "=", "+", "-", "@", "\t", "\r" ].freeze

    COLUMNS = [
      [ "Employee number", ->(employee, csv) { csv.text(employee.employee_number) } ],
      [ "First name", ->(employee, csv) { csv.text(employee.first_name) } ],
      [ "Last name", ->(employee, csv) { csv.text(employee.last_name) } ],
      [ "Email", ->(employee, csv) { csv.text(employee.email) } ],
      [ "Country", ->(employee, csv) { csv.text(employee.country.name) } ],
      [ "Department", ->(employee, csv) { csv.text(employee.department.name) } ],
      [ "Job title", ->(employee, csv) { csv.text(employee.job_title.name) } ],
      [ "Hire date", ->(employee, _csv) { employee.hire_date.iso8601 } ],
      [ "Status", ->(employee, _csv) { employee.status } ],
      [ "Salary", ->(employee, _csv) { employee.salary_amount.to_s("F") } ],
      [ "Currency", ->(employee, _csv) { employee.currency_code } ],
      [ "Salary (USD)", ->(employee, _csv) { employee.salary_usd.to_s("F") } ]
    ].freeze

    def self.call(employees)
      new(employees).call
    end

    def initialize(employees)
      @employees = employees
    end

    def call
      csv = CSV.generate do |out|
        out << COLUMNS.map(&:first)
        @employees.each { |employee| out << COLUMNS.map { |_name, value| value.call(employee, self) } }
      end

      BYTE_ORDER_MARK + csv
    end

    def text(value)
      value.start_with?(*FORMULA_TRIGGERS) ? "'#{value}" : value
    end
  end
end
