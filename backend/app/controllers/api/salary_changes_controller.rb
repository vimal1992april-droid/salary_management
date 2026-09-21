module Api
  class SalaryChangesController < ApplicationController
    def index
      changes = find_employee.salary_changes.newest_first.includes(:changed_by)

      render json: { data: changes.map { |change| SalaryChangeSerializer.new(change) } }
    end

    def create
      employee = find_employee
      change = Employees::ChangeSalary.call(employee: employee, changed_by: Current.user, **change_params)

      render json: { data: SalaryChangeSerializer.new(change), employee: EmployeeSerializer.new(employee) },
             status: :created
    end

    private

    def find_employee
      Employee.includes(:country, :department, :job_title, :currency).find(params[:employee_id])
    end

    def change_params
      params.expect(salary_change: %i[new_amount currency_code effective_on reason]).to_h.symbolize_keys
    end
  end
end
