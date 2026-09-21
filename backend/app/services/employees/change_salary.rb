module Employees
  # Changes an employee's salary and records why, in one transaction: either the history entry and the
  # new salary are both saved or neither is. Raises ActiveRecord::RecordInvalid for bad input.
  #
  #   Employees::ChangeSalary.call(employee:, new_amount: 110_000, effective_on: Date.current,
  #                                reason: "Annual review", changed_by: Current.user)
  class ChangeSalary
    def self.call(**options)
      new(**options).call
    end

    def initialize(employee:, new_amount:, effective_on:, reason:, changed_by:, currency_code: nil)
      @employee = employee
      @new_amount = new_amount
      @currency_code = currency_code
      @effective_on = effective_on
      @reason = reason
      @changed_by = changed_by
    end

    def call
      Employee.transaction do
        # Lock the row so two simultaneous changes cannot both start from the same "previous" salary.
        @employee.lock!

        change = SalaryChange.create!(
          employee: @employee,
          previous_amount: @employee.salary_amount,
          previous_currency_code: @employee.currency_code,
          new_amount: @new_amount,
          new_currency_code: @currency_code.presence || @employee.currency_code,
          effective_on: @effective_on,
          reason: @reason,
          changed_by: @changed_by
        )
        @employee.update!(salary_amount: change.new_amount, currency_code: change.new_currency_code)
        change
      end
    end
  end
end
