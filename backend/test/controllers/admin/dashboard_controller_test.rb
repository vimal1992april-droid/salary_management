require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  include InsightsHelper

  setup { sign_in_as_admin }

  test "shows the headline numbers, each linking to its data" do
    paid(100_000)
    paid(200_000)
    create(:employee, status: "inactive")
    create(:salary_change, employee: create(:employee, status: "inactive")) # inactive, so the pay figures stay those of the two above

    get admin_root_url

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select ".kpi", minimum: 6
    assert_select ".kpi .kpi-label", text: "Employees"
    assert_select ".kpi a[href=?]", admin_table_path("employees")
    assert_select ".kpi a[href=?]", admin_table_path("salary_changes")
    assert_select ".kpi", text: /Average salary.*150,000/m # the two active US employees, in USD
    assert_select ".kpi", text: /Payroll.*300,000/m
  end

  test "draws the charts" do
    paid(100_000)

    get admin_root_url

    assert_select "figure.chart", 6
    assert_select "svg.chart[role=img]", 6
    assert_select "figcaption", text: /Headcount by department/
    assert_select "figcaption", text: /Headcount by country/
    assert_select "figcaption", text: /Hires per year/
    assert_select "figcaption", text: /Salary changes per month/
    assert_select "figcaption", text: /Salary distribution/
    assert_select "figcaption", text: /Active and inactive/
  end

  test "names from the data are escaped in the charts" do
    create(:employee, department: create(:department, name: "<b onmouseover=x>Ops</b>"))

    get admin_root_url

    assert_not_includes response.body, "<b onmouseover"
  end

  test "an empty system still shows the dashboard" do
    get admin_root_url

    assert_response :success
    assert_select "figure.chart", 6
    assert_match(/No data/, response.body)
  end

  test "costs the same number of queries however much data there is" do
    create_list(:employee, 2)
    get admin_root_url # warm up
    few = count_queries { get admin_root_url }

    create_list(:employee, 20)
    many = count_queries { get admin_root_url }

    assert_equal few, many
  end
end
