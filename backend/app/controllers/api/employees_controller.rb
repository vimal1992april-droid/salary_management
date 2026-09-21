module Api
  class EmployeesController < ApplicationController
    include EmployeeSearchable

    CREATE_FIELDS = %i[
      employee_number first_name last_name email country_id department_id job_title_id
      hire_date salary_amount currency_code status
    ].freeze
    UPDATE_FIELDS = %i[first_name last_name email country_id department_id job_title_id hire_date status].freeze
    # The number is an identifier, and salary and currency change only through salary changes so that
    # every change leaves a history. Sending them is an error rather than being silently ignored.
    READ_ONLY_ON_UPDATE = %w[employee_number salary_amount currency_code].freeze

    before_action :reject_read_only_fields, only: :update

    def index
      result = Employees::Search.call(**search_params)

      render json: {
        data: result.records.map { |employee| EmployeeSerializer.new(employee) },
        meta: { page: result.page, per_page: result.per_page, total: result.total, total_pages: result.total_pages }
      }
    end

    def show
      render json: { data: EmployeeSerializer.new(find_employee) }
    end

    def create
      employee = Employee.create!(params.expect(employee: CREATE_FIELDS))

      render json: { data: EmployeeSerializer.new(employee) }, status: :created
    end

    def update
      employee = find_employee
      employee.update!(params.expect(employee: UPDATE_FIELDS))

      render json: { data: EmployeeSerializer.new(employee) }
    end

    private

    def find_employee
      Employee.includes(:country, :department, :job_title, :currency).find(params[:id])
    end

    def reject_read_only_fields
      sent = params[:employee].respond_to?(:keys) ? params[:employee].keys & READ_ONLY_ON_UPDATE : []
      return if sent.empty?

      render_error(:read_only_field, "These fields cannot be changed here: #{sent.sort.join(', ')}",
                   status: :unprocessable_entity,
                   details: sent.index_with { [ "cannot be changed with this request" ] })
    end
  end
end
