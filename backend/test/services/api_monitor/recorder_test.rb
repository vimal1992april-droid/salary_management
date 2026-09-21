require "test_helper"

class ApiMonitor::RecorderTest < ActiveSupport::TestCase
  ATTRIBUTES = {
    http_method: "POST", path: "/api/session", query_string: "", route: "/api/session(.:format)", status: 201,
    duration_ms: 12.345, user_id: nil, ip_address: "203.0.113.9",
    request_body: { email: "asha@acme.example", password: "hunter2-hunter2" }.to_json,
    request_content_type: "application/json",
    response_body: { user: { id: 1, email: "asha@acme.example" } }.to_json, response_content_type: "application/json; charset=utf-8"
  }.freeze

  def record(**overrides)
    ApiMonitor::Recorder.call(**ATTRIBUTES.merge(overrides))
  end

  test "stores what happened, with the payloads" do
    stored = record(user_id: 7)

    assert_predicate stored, :persisted?
    assert_equal "POST", stored.http_method
    assert_equal "/api/session", stored.path
    assert_equal 201, stored.status
    assert_in_delta 12.35, stored.duration_ms, 0.01
    assert_equal 7, stored.user_id
    assert_equal "203.0.113.9", stored.ip_address
    assert_equal "asha@acme.example", JSON.parse(stored.request_body)["email"]
    assert_equal 1, JSON.parse(stored.response_body).dig("user", "id")
    assert_equal "application/json", stored.request_content_type
    assert_not stored.request_truncated
    assert_not stored.response_truncated
  end

  test "names the route without its format suffix, so one endpoint is one name" do
    assert_equal "/api/session", record(route: "/api/session(.:format)").route
    assert_equal "/api/employees/:id", record(route: "/api/employees/:id(.:format)").route
  end

  test "a request that matched no route has none" do
    assert_nil record(route: nil, path: "/api/nope", status: 404).route
  end

  test "never stores a secret from the request or the response" do
    stored = record(response_body: { token: "tok-999" }.to_json)

    assert_not_includes stored.request_body, "hunter2"
    assert_not_includes stored.response_body, "tok-999"
  end

  test "hides secrets in the query string too" do
    stored = record(http_method: "GET", query_string: "q=asha&access_token=abc123")

    assert_not_includes stored.query_string, "abc123"
    assert_equal "asha", Rack::Utils.parse_query(stored.query_string)["q"]
  end

  test "an empty query string is stored as nothing" do
    assert_nil record(query_string: "").query_string
  end

  test "marks a payload that was cut" do
    huge = { rows: Array.new(4_000) { |index| { name: "Employee number #{index}" } } }.to_json

    stored = record(response_body: huge)

    assert stored.response_truncated
    assert_not stored.request_truncated
    assert_operator stored.response_body.bytesize, :<=, ApiMonitor::Redactor::STORE_LIMIT
  end

  test "keeps a very long path within what the column can hold" do
    stored = record(path: "/api/#{'a' * 5_000}")

    assert_operator stored.path.length, :<=, ApiMonitor::Recorder::PATH_LIMIT
  end

  test "keeps only the newest rows once the table outgrows its limit" do
    with_monitor_settings(max_rows: 3, prune_every: 1) do
      5.times { record }

      assert_equal 3, ApiRequest.count
    end
  end

  test "checks the size of the table only now and then" do
    with_monitor_settings(max_rows: 3, prune_every: 1_000_000_000) do
      5.times { record }

      assert_equal 5, ApiRequest.count
    end
  end
end
