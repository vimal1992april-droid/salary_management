require "test_helper"

class Api::SalaryChangesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @hr = sign_in
    usd = create(:currency, code: "USD", rate_to_usd: 1)
    @employee = create(:employee, country: create(:country, currency: usd), salary_amount: 100_000,
                                  hire_date: Date.new(2020, 1, 1))
  end

  def error
    response.parsed_body["error"]
  end

  def valid_change(**overrides)
    { new_amount: "110000", effective_on: "2024-04-01", reason: "Annual review" }.merge(overrides)
  end

  # --- authentication -------------------------------------------------------

  test "both actions require a session" do
    delete api_session_url

    get api_employee_salary_changes_url(@employee)
    assert_response :unauthorized
    post api_employee_salary_changes_url(@employee), params: { salary_change: valid_change }, as: :json
    assert_response :unauthorized
  end

  # --- GET /api/employees/:employee_id/salary_changes -----------------------

  test "index lists the history newest first" do
    create(:salary_change, employee: @employee, effective_on: Date.new(2022, 1, 1), reason: "First")
    create(:salary_change, employee: @employee, effective_on: Date.new(2023, 1, 1), reason: "Second")

    get api_employee_salary_changes_url(@employee)

    assert_response :success
    assert_equal %w[Second First], response.parsed_body["data"].map { |change| change["reason"] }
  end

  test "index describes each change" do
    change = create(:salary_change, employee: @employee, previous_amount: 80_000, new_amount: 90_000,
                                    effective_on: Date.new(2024, 4, 1), reason: "Annual review", changed_by: @hr)

    get api_employee_salary_changes_url(@employee)

    assert_equal(
      {
        "id" => change.id, "effective_on" => "2024-04-01", "reason" => "Annual review",
        "previous_salary" => { "amount" => "80000.0", "currency" => "USD" },
        "new_salary" => { "amount" => "90000.0", "currency" => "USD" },
        "changed_by" => { "id" => @hr.id, "email" => @hr.email },
        "created_at" => change.created_at.iso8601(3)
      },
      response.parsed_body["data"].first
    )
  end

  test "index shows imported history without a user as having no author" do
    create(:salary_change, employee: @employee, changed_by: nil)

    get api_employee_salary_changes_url(@employee)

    assert_nil response.parsed_body["data"].first["changed_by"]
  end

  test "index only returns the requested employee's history" do
    create(:salary_change, employee: @employee)
    create(:salary_change)

    get api_employee_salary_changes_url(@employee)

    assert_equal 1, response.parsed_body["data"].size
  end

  test "index for an unknown employee is a 404" do
    get api_employee_salary_changes_url(employee_id: 0)

    assert_response :not_found
    assert_equal "not_found", error["code"]
  end

  # --- POST /api/employees/:employee_id/salary_changes ----------------------

  test "create records the change against the signed-in user and returns the updated employee" do
    assert_difference -> { @employee.salary_changes.count }, 1 do
      post api_employee_salary_changes_url(@employee), params: { salary_change: valid_change }, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Annual review", body.dig("data", "reason")
    assert_equal({ "amount" => "100000.0", "currency" => "USD" }, body.dig("data", "previous_salary"))
    assert_equal({ "amount" => "110000.0", "currency" => "USD" }, body.dig("data", "new_salary"))
    assert_equal @hr.id, body.dig("data", "changed_by", "id")
    assert_equal "110000.0", body.dig("employee", "salary", "amount")
  end

  test "create makes the new salary visible on the employee" do
    post api_employee_salary_changes_url(@employee), params: { salary_change: valid_change }, as: :json

    get api_employee_url(@employee)

    assert_equal "110000.0", response.parsed_body.dig("data", "salary", "amount")
  end

  test "create can move the employee to another currency" do
    create(:currency, code: "GBP", rate_to_usd: "1.27")

    post api_employee_salary_changes_url(@employee),
         params: { salary_change: valid_change(new_amount: "80000", currency_code: "GBP") }, as: :json

    assert_response :created
    assert_equal "GBP", response.parsed_body.dig("employee", "salary", "currency")
  end

  test "create returns 422 with the errors per field and changes nothing" do
    assert_no_difference -> { SalaryChange.count } do
      post api_employee_salary_changes_url(@employee),
           params: { salary_change: valid_change(new_amount: "100000", reason: "") }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "validation_failed", error["code"]
    assert_equal [ "must differ from the current salary" ], error.dig("details", "new_amount")
    assert_equal [ "can't be blank" ], error.dig("details", "reason")
    assert_equal 100_000, @employee.reload.salary_amount
  end

  test "create without a salary_change object is a 400" do
    post api_employee_salary_changes_url(@employee), params: {}, as: :json

    assert_response :bad_request
  end

  test "create for an unknown employee is a 404" do
    post api_employee_salary_changes_url(employee_id: 0), params: { salary_change: valid_change }, as: :json

    assert_response :not_found
  end
end
