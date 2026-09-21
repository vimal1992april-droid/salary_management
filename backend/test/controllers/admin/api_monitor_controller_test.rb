require "test_helper"

class Admin::ApiMonitorControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  def call(**attributes)
    create(:api_request, { created_at: 10.minutes.ago }.merge(attributes))
  end

  test "every monitor page sends a signed-out visitor to the sign-in page" do
    recorded = call
    delete admin_logout_url

    [ admin_api_monitor_url, admin_api_requests_url, admin_api_request_url(recorded) ].each do |url|
      get url

      assert_redirected_to admin_login_url, "#{url} was open to a visitor who is not signed in"
    end
  end

  test "the panel is reachable from the navigation" do
    get admin_root_url

    assert_select "nav a[href=?]", admin_api_monitor_path, text: /API monitor/
  end

  # --- the live check -------------------------------------------------------------------------------------------------

  test "shows whether the system is up right now" do
    get admin_api_monitor_url

    assert_response :success
    assert_select "h1", "API monitor"
    assert_select ".live .live-database", /Database.*up/m
    assert_select ".live .live-recording", /Recording/
  end

  test "says so when recording is off, since the numbers below would then stand still" do
    with_monitor_settings(enabled: false) do
      get admin_api_monitor_url
    end

    assert_select ".live .live-recording", /off/i
  end

  # --- the numbers ------------------------------------------------------------------------------------------------------

  test "summarises the last day" do
    call(status: 200, duration_ms: 10)
    call(status: 404, duration_ms: 20)
    call(status: 500, duration_ms: 30)
    call(status: 200, duration_ms: 40)

    get admin_api_monitor_url

    assert_select ".kpi", text: /Calls \(24 h\).*4/m
    assert_select ".kpi", text: /Server errors.*25(\.0)?%/m
    assert_select ".kpi", text: /Client errors.*1/m
    assert_select ".kpi", text: /Average time.*25(\.0)? ms/m
    assert_select ".kpi", text: /95th percentile/
  end

  test "draws the calls of each hour and how their statuses divide" do
    call(status: 200)
    call(status: 500)

    get admin_api_monitor_url

    assert_select "figure.chart", 2
    assert_select "figcaption", text: /Calls per hour/
    assert_select "figcaption", text: /Statuses/
  end

  test "an empty log still shows the page" do
    get admin_api_monitor_url

    assert_response :success
    assert_select "table.endpoints tbody tr", ApiMonitor::Endpoints.all.size
    assert_select ".kpi", text: /Calls \(24 h\).*0/m
  end

  # --- the endpoints ------------------------------------------------------------------------------------------------------

  test "lists every endpoint with its state" do
    call(route: "/api/employees/:id", path: "/api/employees/1", status: 200)
    call(route: "/api/lookups", status: 500)

    get admin_api_monitor_url

    assert_select "table.endpoints tbody tr", 17
    assert_select "tr:has(td.path:contains('/api/employees/:id')) .pill.healthy", text: "healthy"
    assert_select "tr:has(td.path:contains('/api/lookups')) .pill.failing", text: "failing"
    assert_select "tr:has(td.path:contains('/api/health')) .pill.idle", text: "idle"
  end

  test "names the method, the path and the code behind each endpoint" do
    get admin_api_monitor_url

    assert_select "tr:has(td.path:contains('/api/employees/:id')) td.method", text: /GET|PATCH/
    assert_select "td.action", text: "api/employees#show"
  end

  test "shows the calls, the timings and the last call of an endpoint" do
    call(route: "/api/lookups", status: 200, duration_ms: 20, created_at: 5.minutes.ago)
    call(route: "/api/lookups", status: 422, duration_ms: 40, created_at: 3.hours.ago)

    get admin_api_monitor_url

    row = css_select("tr:has(td.path)").find { |candidate| candidate.at_css("td.path").text.include?("/api/lookups") }
    assert_equal "2", row.at_css("td.calls").text.strip
    assert_equal "30.0 ms", row.at_css("td.average").text.strip
    assert_match(/5 minutes ago/, row.at_css("td.last-called").text)
    assert_equal "200", row.at_css("td.last-status").text.strip
  end

  test "each endpoint links to its own calls" do
    get admin_api_monitor_url

    assert_select "a[href=?]", admin_api_requests_path(http_method: "GET", route: "/api/employees/:id")
  end

  test "says how many calls matched no endpoint, and links to them" do
    call(route: nil, path: "/api/nope", status: 404)

    get admin_api_monitor_url

    assert_select ".unmatched", /1 call matched no endpoint/
    assert_select ".unmatched a[href=?]", admin_api_requests_path(route: ApiMonitor::Log::UNMATCHED)
  end

  test "explains what the states mean" do
    get admin_api_monitor_url

    assert_select ".state-help", /idle.*healthy.*degraded.*failing/m
  end

  test "text from recorded calls is escaped" do
    call(route: nil, path: "/api/<script>alert(1)</script>", status: 404)

    get admin_api_monitor_url

    assert_not_includes response.body, "<script>alert(1)"
  end

  test "costs the same number of queries however many calls are recorded" do
    call
    get admin_api_monitor_url # warm up
    few = count_queries { get admin_api_monitor_url }

    30.times { call(route: "/api/lookups") }
    many = count_queries { get admin_api_monitor_url }

    assert_equal few, many
  end
end
