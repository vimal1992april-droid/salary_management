require "test_helper"

class ApiMonitor::StatsTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 9, 22, 15, 30).freeze

  setup { travel_to NOW }

  def stats
    ApiMonitor::Stats.call
  end

  def call(status: 200, at: 10.minutes.ago, **attributes)
    create(:api_request, { status: status, created_at: at }.merge(attributes))
  end

  def row_for(label)
    stats.endpoints.find { |row| row.endpoint.label == label }
  end

  # --- the summary ------------------------------------------------------------------------------------------------

  test "counts the calls of the last day by the class of their status" do
    call(status: 200, duration_ms: 10)
    call(status: 201, duration_ms: 20)
    call(status: 404, duration_ms: 30)
    call(status: 500, duration_ms: 40)

    summary = stats.summary

    assert_equal 4, summary.total
    assert_equal({ "2xx" => 2, "3xx" => 0, "4xx" => 1, "5xx" => 1 }, summary.by_class)
    assert_equal 1, summary.client_errors
    assert_equal 1, summary.server_errors
    assert_in_delta 25.0, summary.average_ms, 0.01
    assert_in_delta 38.5, summary.p95_ms, 0.01
  end

  test "the share of calls that failed on the server" do
    3.times { call(status: 200) }
    call(status: 503)

    assert_in_delta 25.0, stats.summary.server_error_percent, 0.01
  end

  test "ignores what is more than a day old" do
    call(status: 200)
    call(status: 500, at: 25.hours.ago)

    assert_equal 1, stats.summary.total
    assert_equal 0, stats.summary.server_errors
  end

  test "an empty log gives zeros, not errors" do
    summary = stats.summary

    assert_equal 0, summary.total
    assert_equal({ "2xx" => 0, "3xx" => 0, "4xx" => 0, "5xx" => 0 }, summary.by_class)
    assert_nil summary.average_ms
    assert_nil summary.p95_ms
    assert_equal 0, summary.server_error_percent
    assert_equal 24, stats.hourly.size
    assert_equal [ 0 ], stats.hourly.pluck(:value).uniq
  end

  # --- each endpoint ------------------------------------------------------------------------------------------------

  test "has a row for every endpoint, called or not" do
    assert_equal ApiMonitor::Endpoints.all.size, stats.endpoints.size
  end

  test "counts the calls, the failures and the timings of one endpoint" do
    call(route: "/api/employees/:id", path: "/api/employees/1", status: 200, duration_ms: 10)
    call(route: "/api/employees/:id", path: "/api/employees/2", status: 404, duration_ms: 30)
    call(route: "/api/employees/:id", path: "/api/employees/3", status: 500, duration_ms: 50)
    call(route: "/api/employees", status: 200)

    row = row_for("GET /api/employees/:id")

    assert_equal 3, row.calls
    assert_equal 1, row.client_errors
    assert_equal 1, row.server_errors
    assert_in_delta 30.0, row.average_ms, 0.01
    assert_equal 1, row_for("GET /api/employees").calls
  end

  test "keeps a GET and a POST of the same path apart" do
    call(route: "/api/employees", http_method: "GET")
    call(route: "/api/employees", http_method: "POST", status: 201)
    call(route: "/api/employees", http_method: "POST", status: 201)

    assert_equal 1, row_for("GET /api/employees").calls
    assert_equal 2, row_for("POST /api/employees").calls
  end

  test "remembers when an endpoint was last called and how that call ended" do
    call(route: "/api/lookups", status: 500, at: 3.hours.ago)
    call(route: "/api/lookups", status: 200, at: 20.minutes.ago)

    row = row_for("GET /api/lookups")

    assert_in_delta 20.minutes.ago.to_f, row.last_called_at.to_f, 1
    assert_equal 200, row.last_status
  end

  # --- what a status means -------------------------------------------------------------------------------------------

  test "an endpoint that has not been called is idle" do
    assert_equal :idle, row_for("GET /api/lookups").state
    assert_nil row_for("GET /api/lookups").last_called_at
    assert_nil row_for("GET /api/lookups").last_status
  end

  test "an endpoint with calls and no server error is healthy, whatever the callers got wrong" do
    call(route: "/api/lookups", status: 200)
    call(route: "/api/lookups", status: 422)

    assert_equal :healthy, row_for("GET /api/lookups").state
  end

  test "an endpoint that failed earlier but answered well since is degraded" do
    call(route: "/api/lookups", status: 500, at: 2.hours.ago)
    call(route: "/api/lookups", status: 200, at: 5.minutes.ago)

    assert_equal :degraded, row_for("GET /api/lookups").state
  end

  test "an endpoint whose latest call failed on the server is failing" do
    call(route: "/api/lookups", status: 200, at: 2.hours.ago)
    call(route: "/api/lookups", status: 502, at: 5.minutes.ago)

    assert_equal :failing, row_for("GET /api/lookups").state
  end

  test "an endpoint whose only calls are older than a day is idle again" do
    call(route: "/api/lookups", status: 500, at: 30.hours.ago)

    assert_equal :idle, row_for("GET /api/lookups").state
  end

  # --- calls that matched nothing -----------------------------------------------------------------------------------------

  test "counts calls that matched no endpoint separately" do
    call(route: nil, path: "/api/nope", status: 404)
    call(route: nil, path: "/api/also-nope", status: 404)
    call(route: "/api/lookups")

    assert_equal 2, stats.unmatched
    assert_equal 3, stats.summary.total
  end

  # --- the last day, hour by hour ---------------------------------------------------------------------------------------

  test "counts the calls of each of the last 24 hours, the current one last" do
    call(at: Time.utc(2026, 9, 22, 15, 10))
    call(at: Time.utc(2026, 9, 22, 15, 5))
    call(at: Time.utc(2026, 9, 22, 14, 50))
    call(at: Time.utc(2026, 9, 21, 16, 5))
    call(at: Time.utc(2026, 9, 21, 15, 59)) # the hour before the first bucket

    hourly = stats.hourly

    assert_equal 24, hourly.size
    assert_equal "16:00", hourly.first[:label]
    assert_equal "15:00", hourly.last[:label]
    assert_equal 2, hourly.last[:value]
    assert_equal 1, hourly[-2][:value]
    assert_equal 1, hourly.first[:value]
    assert_equal 4, hourly.sum { |hour| hour[:value] }
  end

  test "the summary and the endpoints look at the same 24 hours as the chart" do
    call(at: Time.utc(2026, 9, 21, 16, 1))
    call(at: Time.utc(2026, 9, 21, 15, 59))

    assert_equal 1, stats.summary.total
  end

  # --- cost ---------------------------------------------------------------------------------------------------------------

  test "costs the same number of queries however many calls were recorded" do
    call
    few = count_queries { stats }

    50.times { call(route: "/api/lookups", status: [ 200, 404, 500 ].sample) }
    many = count_queries { stats }

    assert_equal few, many
  end
end
