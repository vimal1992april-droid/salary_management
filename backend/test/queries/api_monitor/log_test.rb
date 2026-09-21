require "test_helper"

class ApiMonitor::LogTest < ActiveSupport::TestCase
  def page(**options)
    ApiMonitor::Log.page(**options)
  end

  def paths(**options)
    page(**options).records.map(&:path)
  end

  test "lists the newest call first" do
    older = create(:api_request, path: "/api/older", created_at: 2.hours.ago)
    newer = create(:api_request, path: "/api/newer", created_at: 1.hour.ago)

    assert_equal [ newer.id, older.id ], page.records.map(&:id)
  end

  test "does not load the payloads for a list" do
    create(:api_request, request_body: '{"a":1}', response_body: '{"b":2}')

    record = page.records.first

    assert_raises(ActiveModel::MissingAttributeError) { record.response_body }
    assert_raises(ActiveModel::MissingAttributeError) { record.request_body }
    assert_equal 200, record.status
  end

  # --- paging ---------------------------------------------------------------------------------------------------

  test "pages 25 at a time, and says how many there are" do
    create_list(:api_request, 30)

    first = page
    second = page(page: 2)

    assert_equal [ 25, 5 ], [ first.records.size, second.records.size ]
    assert_equal [ 30, 2, 2 ], [ first.total, first.total_pages, second.page ]
  end

  test "a page size and page number that make no sense are put right" do
    create_list(:api_request, 3)

    assert_equal 100, page(per_page: "9999").per_page
    assert_equal 25, page(per_page: "abc").per_page
    assert_equal 1, page(page: "-2").page
    assert_equal 1, page(page: "99").page
  end

  # --- filters ----------------------------------------------------------------------------------------------------

  test "filters by method" do
    create(:api_request, http_method: "GET", path: "/api/a")
    create(:api_request, http_method: "POST", path: "/api/b")

    assert_equal [ "/api/b" ], paths(http_method: "POST")
    assert_equal [ "/api/b" ], paths(http_method: "post")
  end

  test "filters by an exact status, or by the class of a status" do
    create(:api_request, status: 200, path: "/api/ok")
    create(:api_request, status: 404, path: "/api/missing")
    create(:api_request, status: 422, path: "/api/invalid")
    create(:api_request, status: 500, path: "/api/broken")

    assert_equal [ "/api/missing" ], paths(status: "404")
    assert_equal %w[/api/invalid /api/missing], paths(status: "4xx").sort
    assert_equal [ "/api/broken" ], paths(status: "5xx")
    assert_equal [ "/api/ok" ], paths(status: "2XX")
  end

  test "filters by route" do
    create(:api_request, route: "/api/employees/:id", path: "/api/employees/1")
    create(:api_request, route: "/api/employees", path: "/api/employees")

    assert_equal [ "/api/employees/1" ], paths(route: "/api/employees/:id")
  end

  test "filters by the calls that matched no route" do
    create(:api_request, route: nil, path: "/api/nope")
    create(:api_request, route: "/api/lookups", path: "/api/lookups")

    assert_equal [ "/api/nope" ], paths(route: ApiMonitor::Log::UNMATCHED)
  end

  test "searches the path, ignoring case, with wildcards taken literally" do
    create(:api_request, path: "/api/employees/42")
    create(:api_request, path: "/api/lookups")
    create(:api_request, path: "/api/100%")

    assert_equal [ "/api/employees/42" ], paths(q: "EMPLOYEES")
    assert_equal [ "/api/100%" ], paths(q: "%")
    assert_equal [], paths(q: "_")
  end

  test "also finds a call by the text of its query string" do
    create(:api_request, path: "/api/employees", query_string: "q=asha")
    create(:api_request, path: "/api/lookups")

    assert_equal [ "/api/employees" ], paths(q: "q=asha")
  end

  test "filters by user" do
    user = create(:user)
    create(:api_request, user_id: user.id, path: "/api/mine")
    create(:api_request, user_id: nil, path: "/api/anonymous")

    assert_equal [ "/api/mine" ], paths(user_id: user.id.to_s)
  end

  test "filters by the slowest calls" do
    create(:api_request, duration_ms: 5, path: "/api/fast")
    create(:api_request, duration_ms: 250, path: "/api/slow")

    assert_equal [ "/api/slow" ], paths(min_duration: "100")
  end

  test "combines filters, all of which must hold" do
    create(:api_request, http_method: "GET", status: 500, path: "/api/a")
    create(:api_request, http_method: "POST", status: 500, path: "/api/b")
    create(:api_request, http_method: "GET", status: 200, path: "/api/c")

    assert_equal [ "/api/a" ], paths(http_method: "GET", status: "5xx")
  end

  test "ignores a filter that makes no sense instead of failing" do
    create(:api_request, path: "/api/a")

    %w[abc 9xx 99999 -3].each { |status| assert_equal 1, page(status: status).total, "status #{status}" }
    assert_equal 1, page(http_method: "TELEPORT").total
    assert_equal 1, page(user_id: "abc").total
    assert_equal 1, page(min_duration: "fast").total
    assert_equal 1, page(user_id: "").total
  end

  # --- one call -----------------------------------------------------------------------------------------------------

  test "finds one call with its payloads" do
    call = create(:api_request, request_body: '{"a":1}', response_body: '{"b":2}')

    found = ApiMonitor::Log.find(call.id)

    assert_equal '{"b":2}', found.response_body
    assert_raises(ActiveRecord::RecordNotFound) { ApiMonitor::Log.find(0) }
  end
end
