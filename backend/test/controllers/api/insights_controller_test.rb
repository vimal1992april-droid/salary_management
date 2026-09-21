require "test_helper"

class Api::InsightsControllerTest < ActionDispatch::IntegrationTest
  include InsightsHelper

  def body
    response.parsed_body
  end

  test "every insight requires a session" do
    get api_insights_overview_url
    assert_response :unauthorized
    get api_insights_salary_stats_url(group_by: "country")
    assert_response :unauthorized
    get api_insights_distribution_url
    assert_response :unauthorized
    get api_insights_top_earners_url
    assert_response :unauthorized
  end

  test "overview returns the headline numbers, with money as strings" do
    sign_in
    paid(100_000)
    paid(50_000)

    get api_insights_overview_url

    assert_response :success
    assert_equal(
      { "headcount" => 2, "countries" => 1, "departments" => 2, "payroll_usd" => "150000.0",
        "average_salary_usd" => "75000.0", "median_salary_usd" => "75000.0", "rates_as_of" => "2026-01-01" },
      body["data"]
    )
  end

  test "salary_stats returns one row per group with the pay range" do
    sign_in
    engineering = create(:department, name: "Engineering")
    [ 10_000, 20_000, 30_000, 40_000, 50_000 ].each { |amount| paid(amount, department: engineering) }

    get api_insights_salary_stats_url(group_by: "department")

    assert_response :success
    assert_equal(
      [ { "group" => { "id" => engineering.id, "name" => "Engineering" }, "headcount" => 5, "min" => "10000.0",
          "p25" => "20000.0", "median" => "30000.0", "p75" => "40000.0", "max" => "50000.0", "mean" => "30000.0" } ],
      body["data"]
    )
  end

  test "salary_stats accepts filters" do
    sign_in
    india = create(:country, name: "India", iso_code: "IN", currency: usd)
    paid(10_000, country: india)
    paid(99_000)

    get api_insights_salary_stats_url(group_by: "country", country_id: india.id)

    assert_equal [ "India" ], body["data"].map { |row| row.dig("group", "name") }
  end

  test "salary_stats rejects an unknown grouping with a 400" do
    sign_in

    get api_insights_salary_stats_url(group_by: "salary")

    assert_response :bad_request
    assert_equal "invalid_parameter", body.dig("error", "code")
  end

  test "distribution returns the buckets" do
    sign_in
    [ 100, 400 ].each { |amount| paid(amount) }

    get api_insights_distribution_url(bucket_count: 3)

    assert_response :success
    assert_equal [ 1, 0, 1 ], body.dig("data", "buckets").map { |bucket| bucket["count"] }
    assert_equal [ "100.0", "400.0" ], [ body.dig("data", "min"), body.dig("data", "max") ]
  end

  test "top_earners returns employees in the directory format" do
    sign_in
    paid(50_000, first_name: "Lowest")
    paid(150_000, first_name: "Highest")

    get api_insights_top_earners_url(limit: 1)

    assert_response :success
    assert_equal [ "Highest" ], body["data"].map { |employee| employee["first_name"] }
    assert_equal "150000.0", body["data"].first.dig("salary", "usd")
  end

  test "top_earners can list the lowest paid" do
    sign_in
    paid(50_000, first_name: "Lowest")
    paid(150_000, first_name: "Highest")

    get api_insights_top_earners_url(direction: "asc", limit: 1)

    assert_equal [ "Lowest" ], body["data"].map { |employee| employee["first_name"] }
  end

  test "top_earners rejects an unknown direction with a 400" do
    sign_in

    get api_insights_top_earners_url(direction: "sideways")

    assert_response :bad_request
  end
end
