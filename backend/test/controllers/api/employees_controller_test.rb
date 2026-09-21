require "test_helper"

class Api::EmployeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @usd = create(:currency, code: "USD", rate_to_usd: 1)
    @us = create(:country, name: "United States", iso_code: "US", currency: @usd)
    @engineering = create(:department, name: "Engineering")
    @engineer = create(:job_title, name: "Software Engineer", level: 2)
  end

  def data
    response.parsed_body["data"]
  end

  def error
    response.parsed_body["error"]
  end

  # --- authentication -------------------------------------------------------

  test "every action requires a session" do
    employee = create(:employee)
    delete api_session_url

    get api_employees_url
    assert_response :unauthorized
    get api_employee_url(employee)
    assert_response :unauthorized
    post api_employees_url, params: { employee: { first_name: "Asha" } }, as: :json
    assert_response :unauthorized
    patch api_employee_url(employee), params: { employee: { first_name: "Asha" } }, as: :json
    assert_response :unauthorized
  end

  # --- GET /api/employees ---------------------------------------------------

  test "index describes each employee with salary, country, department and job title" do
    create(:employee, employee_number: "E00001", first_name: "Asha", last_name: "Verma",
                      email: "asha.verma@acme.example", hire_date: Date.new(2022, 3, 1), salary_amount: 90_000,
                      country: @us, department: @engineering, job_title: @engineer)

    get api_employees_url

    assert_response :success
    assert_equal(
      {
        "id" => Employee.last.id, "employee_number" => "E00001", "first_name" => "Asha", "last_name" => "Verma",
        "full_name" => "Asha Verma", "email" => "asha.verma@acme.example", "hire_date" => "2022-03-01",
        "status" => "active",
        "salary" => { "amount" => "90000.0", "currency" => "USD", "usd" => "90000.0" },
        "country" => { "id" => @us.id, "name" => "United States", "iso_code" => "US" },
        "department" => { "id" => @engineering.id, "name" => "Engineering" },
        "job_title" => { "id" => @engineer.id, "name" => "Software Engineer", "level" => 2 }
      },
      data.first
    )
  end

  test "index reports pagination in meta" do
    create_list(:employee, 3)

    get api_employees_url, params: { per_page: 2, page: 2 }

    assert_equal 1, data.size
    assert_equal({ "page" => 2, "per_page" => 2, "total" => 3, "total_pages" => 2 }, response.parsed_body["meta"])
  end

  test "index passes filters, search and sort through to the directory query" do
    india = create(:country)
    match = create(:employee, first_name: "Priya", country: india, salary_amount: 50_000)
    create(:employee, first_name: "Priya", salary_amount: 60_000)
    create(:employee, first_name: "Other", country: india)

    get api_employees_url, params: { q: "priya", country_id: india.id, sort: "salary", direction: "desc" }

    assert_equal [ match.id ], data.map { |employee| employee["id"] }
  end

  test "index rejects an unknown sort with a 400" do
    get api_employees_url, params: { sort: "password_digest" }

    assert_response :bad_request
    assert_equal "invalid_parameter", error["code"]
    assert_match(/sort/, error["message"])
  end

  test "index costs the same number of queries for a small and a large page" do
    create_list(:employee, 2)
    few = count_queries { get api_employees_url }
    create_list(:employee, 10)
    many = count_queries { get api_employees_url }

    assert_equal few, many
  end

  # --- GET /api/employees/:id -----------------------------------------------

  test "show returns one employee" do
    employee = create(:employee, first_name: "Asha")

    get api_employee_url(employee)

    assert_response :success
    assert_equal employee.id, data["id"]
    assert_equal "Asha", data["first_name"]
  end

  test "show returns 404 in the standard error shape for an unknown employee" do
    get api_employee_url(id: 0)

    assert_response :not_found
    assert_equal "not_found", error["code"]
  end

  # --- POST /api/employees --------------------------------------------------

  test "create adds an employee, paid in the country's currency" do
    assert_difference -> { Employee.count }, 1 do
      post api_employees_url, params: { employee: new_employee_attributes }, as: :json
    end

    assert_response :created
    assert_equal "Nikhil", data["first_name"]
    assert_equal({ "amount" => "120000.0", "currency" => "USD", "usd" => "120000.0" }, data["salary"])
  end

  test "create returns 422 with the validation errors per field" do
    create(:employee, email: "taken@acme.example")

    assert_no_difference -> { Employee.count } do
      post api_employees_url,
           params: { employee: new_employee_attributes.merge(first_name: "", email: "taken@acme.example") }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "validation_failed", error["code"]
    assert_equal [ "can't be blank" ], error.dig("details", "first_name")
    assert_equal [ "has already been taken" ], error.dig("details", "email")
  end

  test "create without an employee object is a 400" do
    post api_employees_url, params: {}, as: :json

    assert_response :bad_request
    assert_equal "bad_request", error["code"]
  end

  # --- PATCH /api/employees/:id ---------------------------------------------

  test "update changes personal, organisational and status fields" do
    employee = create(:employee)

    patch api_employee_url(employee),
          params: { employee: { first_name: "Asha", last_name: "Iyer", department_id: @engineering.id,
                                job_title_id: @engineer.id, country_id: @us.id, status: "inactive" } }, as: :json

    assert_response :success
    employee.reload
    assert_equal "Asha Iyer", employee.full_name
    assert_equal @engineering, employee.department
    assert_equal @engineer, employee.job_title
    assert_equal @us, employee.country
    assert_predicate employee, :inactive?
  end

  test "update cannot change the salary or the employee number" do
    employee = create(:employee, salary_amount: 90_000, employee_number: "E00001")

    patch api_employee_url(employee), params: { employee: { salary_amount: 1, employee_number: "HACKED" } }, as: :json

    assert_response :success
    employee.reload
    assert_equal 90_000, employee.salary_amount
    assert_equal "E00001", employee.employee_number
  end

  test "update returns 422 for invalid data" do
    employee = create(:employee)

    patch api_employee_url(employee), params: { employee: { email: "not-an-email" } }, as: :json

    assert_response :unprocessable_entity
    assert_equal "validation_failed", error["code"]
    assert_predicate error.dig("details", "email"), :present?
  end

  test "update returns 404 for an unknown employee" do
    patch api_employee_url(id: 0), params: { employee: { first_name: "Asha" } }, as: :json

    assert_response :not_found
  end

  private

  def new_employee_attributes
    {
      employee_number: "E90001", first_name: "Nikhil", last_name: "Rao", email: "nikhil.rao@acme.example",
      country_id: @us.id, department_id: @engineering.id, job_title_id: @engineer.id,
      hire_date: "2024-05-01", salary_amount: "120000"
    }
  end
end
