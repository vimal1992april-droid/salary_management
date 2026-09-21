require "test_helper"

class Api::LookupsControllerTest < ActionDispatch::IntegrationTest
  test "requires a session" do
    get api_lookups_url

    assert_response :unauthorized
  end

  test "lists the reference data behind the filters and forms, sorted by name" do
    sign_in
    inr = create(:currency, code: "INR", name: "Indian Rupee", rate_to_usd: "0.012", rate_as_of: Date.new(2026, 1, 1))
    usd = create(:currency, code: "USD", name: "US Dollar", rate_to_usd: "1", rate_as_of: Date.new(2026, 1, 1))
    india = create(:country, name: "India", iso_code: "IN", currency: inr)
    create(:country, name: "Brazil", iso_code: "BR", currency: usd)
    create(:department, name: "Sales")
    create(:department, name: "Engineering")
    create(:job_title, name: "Staff Engineer", level: 4)
    create(:job_title, name: "Account Executive", level: 2)

    get api_lookups_url

    assert_response :success
    body = response.parsed_body
    assert_equal %w[countries currencies departments job_titles], body.keys.sort
    assert_equal %w[Brazil India], body["countries"].map { |country| country["name"] }
    assert_equal({ "id" => india.id, "name" => "India", "iso_code" => "IN", "currency_code" => "INR" },
                 body["countries"].last)
    assert_equal %w[Engineering Sales], body["departments"].map { |department| department["name"] }
    assert_equal [ { "name" => "Account Executive", "level" => 2 }, { "name" => "Staff Engineer", "level" => 4 } ],
                 body["job_titles"].map { |title| title.slice("name", "level") }
    assert_equal({ "code" => "INR", "name" => "Indian Rupee", "rate_to_usd" => "0.012", "rate_as_of" => "2026-01-01" },
                 body["currencies"].find { |currency| currency["code"] == "INR" })
  end
end
