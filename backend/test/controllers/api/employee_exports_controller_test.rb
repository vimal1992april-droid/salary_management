require "test_helper"
require "csv"

class Api::EmployeeExportsControllerTest < ActionDispatch::IntegrationTest
  def rows
    CSV.parse(response.body.delete_prefix("﻿"), headers: true)
  end

  test "requires a session" do
    get api_employee_export_url

    assert_response :unauthorized
  end

  test "downloads the directory as a CSV attachment" do
    sign_in
    create(:employee, first_name: "Asha")

    get api_employee_export_url

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment; filename="employees-\d{4}-\d{2}-\d{2}\.csv"/, response.headers["Content-Disposition"])
    assert_equal [ "Asha" ], rows.map { |row| row["First name"] }
  end

  test "exports every match, not just one page" do
    sign_in
    create_list(:employee, 30)

    get api_employee_export_url, params: { per_page: 5, page: 2 }

    assert_equal 30, rows.size
  end

  test "honours the same filters, search and sort as the directory" do
    sign_in
    india = create(:country, name: "India")
    create(:employee, first_name: "Priya", last_name: "B", country: india)
    create(:employee, first_name: "Priya", last_name: "A", country: india)
    create(:employee, first_name: "Priya", last_name: "Elsewhere")
    create(:employee, first_name: "Other", country: india)

    get api_employee_export_url, params: { q: "priya", country_id: india.id, sort: "name" }

    assert_equal %w[A B], rows.map { |row| row["Last name"] }
  end

  test "rejects an unknown sort like the directory does" do
    sign_in

    get api_employee_export_url, params: { sort: "password_digest" }

    assert_response :bad_request
  end

  test "costs the same number of queries for a small and a large export" do
    sign_in
    create_list(:employee, 2)
    few = count_queries { get api_employee_export_url }
    create_list(:employee, 10)
    many = count_queries { get api_employee_export_url }

    assert_equal few, many
  end
end
