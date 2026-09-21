require "test_helper"

# The monitor as a whole: real requests through the whole stack, and what ends up in the log.
class ApiMonitorTest < ActionDispatch::IntegrationTest
  setup { @user = sign_in } # before the monitor is on, so the sign-in is not part of what is measured

  def last_recorded
    ApiRequest.order(:id).last
  end

  # --- what is recorded ---------------------------------------------------------------------------------------------

  test "records a call with its method, path, route, status and duration" do
    employee = create(:employee)

    with_monitor_settings do
      get api_employee_url(employee)
    end

    call = last_recorded
    assert_equal "GET", call.http_method
    assert_equal "/api/employees/#{employee.id}", call.path
    assert_equal "/api/employees/:id", call.route
    assert_equal 200, call.status
    assert_operator call.duration_ms, :>, 0
    assert_equal "127.0.0.1", call.ip_address
  end

  test "records the response as it was sent" do
    create(:employee)

    with_monitor_settings do
      get api_employees_url
    end

    assert_equal JSON.parse(response.body), JSON.parse(last_recorded.response_body)
    assert_match(%r{application/json}, last_recorded.response_content_type)
  end

  test "records who made the call" do
    with_monitor_settings do
      get api_employees_url
    end

    assert_equal @user.id, last_recorded.user_id
  end

  test "records the payload of a request, and the app still receives it" do
    department = create(:department)
    country = create(:country)
    job_title = create(:job_title)
    payload = { first_name: "Asha", last_name: "Verma", email: "asha.v@acme.example", hire_date: "2024-01-15",
                salary_amount: "88000", department_id: department.id, country_id: country.id,
                job_title_id: job_title.id, employee_number: "E77777" }

    with_monitor_settings do
      post api_employees_url, params: { employee: payload }, as: :json
    end

    assert_response :created
    call = last_recorded
    assert_equal "POST", call.http_method
    assert_equal 201, call.status
    assert_equal "application/json", call.request_content_type
    assert_equal "Asha", JSON.parse(call.request_body).dig("employee", "first_name")
    assert_equal "E77777", JSON.parse(call.response_body).dig("data", "employee_number")
  end

  test "keeps a password out of the log, in what was sent and what was answered" do
    with_monitor_settings do
      post api_session_url, params: { email: @user.email, password: "correct-horse-battery" }, as: :json
    end

    call = last_recorded
    assert_response :created
    assert_not_includes call.request_body, "correct-horse-battery"
    assert_includes call.request_body, "[FILTERED]"
    assert_equal @user.id, call.user_id
  end

  test "keeps secrets out of the query string" do
    with_monitor_settings do
      get api_employees_url(q: "asha", access_token: "abc123")
    end

    assert_not_includes last_recorded.query_string, "abc123"
    assert_includes last_recorded.query_string, "q=asha"
  end

  test "records a refused call, with no user" do
    delete api_session_url
    with_monitor_settings do
      get api_employees_url
    end

    call = last_recorded
    assert_equal 401, call.status
    assert_nil call.user_id
    assert_equal "unauthenticated", JSON.parse(call.response_body).dig("error", "code")
  end

  test "records a call that matched no route" do
    with_monitor_settings do
      get "/api/nope"
    end

    call = last_recorded
    assert_equal 404, call.status
    assert_nil call.route
    assert_equal "/api/nope", call.path
  end

  test "records a call that failed inside the app, and lets the failure carry on" do
    replace_method(Employees::Search, :call, ->(**) { raise "boom" }) do
      with_monitor_settings do
        assert_raises(RuntimeError) { get api_employees_url }
      end
    end

    assert_equal 500, last_recorded.status
    assert_equal "/api/employees", last_recorded.route
  end

  test "describes a file download instead of storing it" do
    create(:employee)

    with_monitor_settings do
      get api_employee_export_url
    end

    call = last_recorded
    assert_response :success
    assert_match(%r{text/csv}, response.media_type)
    assert_match(/\A\[text\/csv, \d+ bytes, not recorded\]\z/, call.response_body)
    assert_equal "/api/employees/export", call.route
  end

  # --- what is not recorded ---------------------------------------------------------------------------------------

  test "records nothing while it is switched off" do
    with_monitor_settings(enabled: false) do
      get api_employees_url
    end

    assert_equal 0, ApiRequest.count
  end

  test "records nothing outside the API, and above all not the admin sign-in with its password" do
    create(:user, :admin, email: "admin@acme.example", password: "correct-horse-battery")

    with_monitor_settings do
      post admin_login_url, params: { email: "admin@acme.example", password: "correct-horse-battery" }
      get admin_root_url
      get "/up"
      get "/employees"
    end

    assert_equal 0, ApiRequest.count
  end

  # --- it must never get in the way -------------------------------------------------------------------------------

  test "an API call still works when the log cannot be written" do
    replace_method(ApiMonitor::Recorder, :call, ->(**) { raise "database is full" }) do
      with_monitor_settings do
        get api_employees_url
      end
    end

    assert_response :success
    assert_equal 0, ApiRequest.count
  end

  test "sits outside the error handling, so it sees the final response" do
    names = Rails.application.middleware.map(&:name)

    assert_operator names.index("ApiRequestLogger"), :<, names.index("ActionDispatch::ShowExceptions")
  end
end
