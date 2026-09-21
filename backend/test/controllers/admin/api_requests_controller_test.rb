require "test_helper"

class Admin::ApiRequestsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  # --- the log ----------------------------------------------------------------------------------------------------------

  test "lists recorded calls, newest first" do
    create(:api_request, path: "/api/older", created_at: 2.hours.ago)
    create(:api_request, path: "/api/newer", created_at: 1.hour.ago)

    get admin_api_requests_url

    assert_response :success
    assert_select "h1", /Calls/
    assert_equal %w[/api/newer /api/older], css_select("tbody td.path").map { |cell| cell.text.strip }
  end

  test "shows what each call was: method, status, time taken, when, and who" do
    user = create(:user, email: "hr@acme.example")
    create(:api_request, http_method: "POST", path: "/api/employees", status: 422, duration_ms: 12.5, user_id: user.id,
                         created_at: Time.utc(2026, 9, 22, 10, 30, 15))

    get admin_api_requests_url

    row = css_select("tbody tr").first
    assert_equal "POST", row.at_css("td.method").text.strip
    assert_equal "422", row.at_css("td.status .status-4xx").text.strip
    assert_equal "12.5 ms", row.at_css("td.duration").text.strip
    assert_equal "2026-09-22 10:30:15 UTC", row.at_css("td.time").text.strip
    assert_equal "hr@acme.example", row.at_css("td.user").text.strip
  end

  test "a call made by nobody signed in says so" do
    create(:api_request, user_id: nil)

    get admin_api_requests_url

    assert_equal "anonymous", css_select("tbody td.user").first.text.strip
  end

  test "each call links to its detail" do
    recorded = create(:api_request)

    get admin_api_requests_url

    assert_select "tbody td.path a[href=?]", admin_api_request_path(recorded)
  end

  test "text from recorded calls is escaped" do
    create(:api_request, path: "/api/<script>alert(1)</script>", query_string: "<img src=x onerror=alert(2)>")

    get admin_api_requests_url

    assert_not_includes response.body, "<script>alert(1)"
    assert_not_includes response.body, "<img src=x"
  end

  test "an empty log says so, and why it might be" do
    get admin_api_requests_url

    assert_response :success
    assert_select ".empty", /No calls recorded/
  end

  # --- filters --------------------------------------------------------------------------------------------------------------

  test "offers every filter, holding the values that were chosen" do
    get admin_api_requests_url(http_method: "POST", status: "5xx", route: "/api/employees", q: "asha", user_id: "3", min_duration: "50")

    assert_select "form.filters[method=get]"
    assert_select "select[name=http_method] option[selected][value=POST]"
    assert_select "select[name=status] option[selected][value=?]", "5xx"
    assert_select "select[name=route] option[selected][value=?]", "/api/employees"
    assert_select "select[name=route] option[value=?]", ApiMonitor::Log::UNMATCHED
    assert_select "input[name=q][value=asha]"
    assert_select "input[name=user_id][value='3']"
    assert_select "input[name=min_duration][value='50']"
  end

  test "filters the list" do
    create(:api_request, http_method: "GET", status: 200, path: "/api/fine")
    create(:api_request, http_method: "POST", status: 500, path: "/api/broken")

    get admin_api_requests_url(status: "5xx")

    assert_equal [ "/api/broken" ], css_select("tbody td.path").map { |cell| cell.text.strip }
    assert_select ".filters-summary", /1 call/
  end

  test "filters by the calls that matched no route" do
    create(:api_request, route: nil, path: "/api/nope", status: 404)
    create(:api_request, route: "/api/lookups", path: "/api/lookups")

    get admin_api_requests_url(route: ApiMonitor::Log::UNMATCHED)

    assert_equal [ "/api/nope" ], css_select("tbody td.path").map { |cell| cell.text.strip }
  end

  test "a filter that makes no sense still shows a page" do
    create(:api_request)

    get admin_api_requests_url(status: "banana", min_duration: "fast", user_id: "x", http_method: "TELEPORT")

    assert_response :success
    assert_select "tbody tr", 1
  end

  test "can clear the filters" do
    get admin_api_requests_url(status: "5xx")

    assert_select "a[href=?]", admin_api_requests_path, text: /Clear/
  end

  # --- paging ------------------------------------------------------------------------------------------------------------------

  test "pages, keeping the filters in the links" do
    create_list(:api_request, 30, status: 500)
    create(:api_request, status: 200)

    get admin_api_requests_url(status: "5xx", page: 2)

    assert_select "tbody tr", 5
    assert_select ".pager", /Page 2 of 2/
    assert_select ".pager a[href*=?]", "status=5xx"
    assert_select ".pager a[href*=?]", "page=1"
  end

  test "costs the same number of queries however many calls are listed" do
    create_list(:api_request, 2)
    get admin_api_requests_url
    few = count_queries { get admin_api_requests_url }

    create_list(:api_request, 20)
    many = count_queries { get admin_api_requests_url }

    assert_equal few, many
  end

  # --- one call -------------------------------------------------------------------------------------------------------------------

  test "shows a call in full: what was asked, what was answered, and how it went" do
    user = create(:user, email: "hr@acme.example")
    recorded = create(:api_request, http_method: "POST", path: "/api/employees", route: "/api/employees", status: 422,
                                    duration_ms: 12.5, user_id: user.id, ip_address: "203.0.113.9",
                                    query_string: "verbose=1", created_at: Time.utc(2026, 9, 22, 10, 30, 15),
                                    request_content_type: "application/json", request_body: '{"employee":{"first_name":"Asha"}}',
                                    response_content_type: "application/json; charset=utf-8",
                                    response_body: '{"error":{"code":"validation_failed"}}')

    get admin_api_request_url(recorded)

    assert_response :success
    assert_select "h1", "POST /api/employees"
    assert_select ".status-4xx", "422"
    assert_select "dd", text: "12.5 ms"
    assert_select "dd", text: "2026-09-22 10:30:15 UTC"
    assert_select "dd", text: "203.0.113.9"
    assert_select "dd", text: "/api/employees"
    assert_select "dd", text: "verbose=1"
    assert_select "dd a[href=?]", admin_record_path("users", user.id), text: "hr@acme.example"
    assert_select "section.request .content-type", "application/json"
    assert_select "section.response .content-type", "application/json; charset=utf-8"
  end

  test "shows each payload as readable JSON" do
    recorded = create(:api_request, request_body: '{"employee":{"first_name":"Asha"}}',
                                    response_body: '{"error":{"code":"validation_failed"}}')

    get admin_api_request_url(recorded)

    assert_select "section.request pre.payload", /"employee": \{\s+"first_name": "Asha"/m
    assert_select "section.response pre.payload", /"code": "validation_failed"/
  end

  test "shows a payload that is not JSON as it was described" do
    recorded = create(:api_request, response_content_type: "text/csv", response_body: "[text/csv, 15 bytes, not recorded]")

    get admin_api_request_url(recorded)

    assert_select "section.response pre.payload", "[text/csv, 15 bytes, not recorded]"
  end

  test "says so when there was no payload" do
    recorded = create(:api_request, request_body: nil, response_body: nil)

    get admin_api_request_url(recorded)

    assert_select "section.request .none", /No payload/
    assert_select "section.response .none", /No payload/
  end

  test "says so when a payload was cut short" do
    recorded = create(:api_request, response_body: '{"rows":[', response_truncated: true)

    get admin_api_request_url(recorded)

    assert_select "section.response .cut", /cut/i
    assert_select "section.request .cut", 0
  end

  test "payloads and text from the call are escaped, never run" do
    recorded = create(:api_request, path: "/api/<script>alert(1)</script>",
                                    request_body: '{"name":"<script>alert(2)</script>"}',
                                    response_body: '{"name":"<img src=x onerror=alert(3)>"}')

    get admin_api_request_url(recorded)

    assert_not_includes response.body, "<script>alert"
    assert_not_includes response.body, "<img src=x"
    assert_includes response.body, "&lt;script&gt;alert(2)"
  end

  test "a call by nobody signed in, or by someone since removed, has no user link" do
    anonymous = create(:api_request, user_id: nil)
    removed = create(:api_request, user_id: 999_999)

    get admin_api_request_url(anonymous)
    assert_select "dd", text: "anonymous"

    get admin_api_request_url(removed)
    assert_select "dd", text: /user #999999 \(removed\)/
  end

  test "a call that matched no route says so" do
    recorded = create(:api_request, route: nil, path: "/api/nope", status: 404)

    get admin_api_request_url(recorded)

    assert_select "dd", text: /matched no route/i
  end

  test "links back to the log" do
    recorded = create(:api_request)

    get admin_api_request_url(recorded)

    assert_select "a[href=?]", admin_api_requests_path, text: /Calls/
  end

  test "a call that is not there is a 404" do
    get admin_api_request_url(999_999)

    assert_response :not_found
    assert_select "h1", /not found/i
  end
end
