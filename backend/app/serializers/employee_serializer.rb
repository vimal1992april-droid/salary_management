# The JSON contract for an employee. Expects country, department, job title and currency to be
# preloaded when serializing many (Employees::Search does this).
class EmployeeSerializer
  def initialize(employee)
    @employee = employee
  end

  def as_json(*)
    {
      id: @employee.id,
      employee_number: @employee.employee_number,
      first_name: @employee.first_name,
      last_name: @employee.last_name,
      full_name: @employee.full_name,
      email: @employee.email,
      hire_date: @employee.hire_date.iso8601,
      status: @employee.status,
      salary: salary,
      country: @employee.country.slice(:id, :name, :iso_code),
      department: @employee.department.slice(:id, :name),
      job_title: @employee.job_title.slice(:id, :name, :level)
    }
  end

  private

  # Amounts are strings so no precision is lost in transit; the client formats them.
  def salary
    {
      amount: @employee.salary_amount.to_s("F"),
      currency: @employee.currency_code,
      usd: @employee.salary_usd.to_s("F")
    }
  end
end
