require "test_helper"

class ApiMonitor::EndpointsTest < ActiveSupport::TestCase
  LABELS = [
    "GET /api/employees", "POST /api/employees", "GET /api/employees/:id", "PATCH /api/employees/:id",
    "GET /api/employees/export", "GET /api/employees/:employee_id/salary_changes",
    "POST /api/employees/:employee_id/salary_changes",
    "GET /api/health", "GET /api/lookups",
    "GET /api/insights/overview", "GET /api/insights/salary_stats", "GET /api/insights/distribution",
    "GET /api/insights/top_earners", "GET /api/insights/outliers",
    "GET /api/session", "POST /api/session", "DELETE /api/session"
  ].freeze

  test "lists every endpoint of the API and nothing else" do
    assert_equal LABELS.sort, ApiMonitor::Endpoints.all.map(&:label).sort
  end

  test "names the controller and action behind each" do
    endpoint = ApiMonitor::Endpoints.all.find { |candidate| candidate.label == "GET /api/employees/:id" }

    assert_equal "api/employees", endpoint.controller
    assert_equal "show", endpoint.action
    assert_equal "GET", endpoint.http_method
    assert_equal "/api/employees/:id", endpoint.path
  end

  test "leaves out the pages, the admin panel and the catch-all: they are not the API" do
    paths = ApiMonitor::Endpoints.all.map(&:path)

    assert paths.all? { |path| path.start_with?("/api/") }
    assert_not_includes paths, "/*path"
  end

  test "shows a path without the format suffix, and an update once rather than as PATCH and PUT" do
    endpoints = ApiMonitor::Endpoints.all

    assert endpoints.none? { |endpoint| endpoint.path.include?("(.:format)") }
    assert_empty endpoints.select { |endpoint| endpoint.http_method == "PUT" }
  end

  test "is ordered by path, and within a path by GET, POST, PATCH, DELETE" do
    labels = ApiMonitor::Endpoints.all.map(&:label)

    assert_equal labels, labels.sort_by { |label| verb, path = label.split; [ path, %w[GET POST PATCH PUT DELETE].index(verb) ] }
    assert_operator labels.index("GET /api/session"), :<, labels.index("POST /api/session")
    assert_operator labels.index("POST /api/session"), :<, labels.index("DELETE /api/session")
  end

  test "matches the route a recorded call carries" do
    route = create(:api_request, route: "/api/employees/:id", http_method: "GET").route

    assert_includes ApiMonitor::Endpoints.all.map(&:path), route
  end
end
