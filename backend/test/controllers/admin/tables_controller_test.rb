require "test_helper"

class Admin::TablesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  # --- who may look -----------------------------------------------------------------------------------------------

  test "every data page sends a signed-out visitor to the sign-in page" do
    department = create(:department)
    delete admin_logout_url

    [ admin_tables_url, admin_table_url("departments"), admin_record_url("departments", department.id) ].each do |url|
      get url

      assert_redirected_to admin_login_url, "#{url} was open to a visitor who is not signed in"
    end
  end

  # --- the list of tables -------------------------------------------------------------------------------------------

  test "lists every table with its row count and a link to it" do
    create_list(:department, 3)

    get admin_tables_url

    assert_response :success
    assert_select "table.tables tbody tr", 8
    assert_select "a[href=?]", admin_table_path("departments"), text: "Departments"
    assert_select "tr:has(a[href=?]) td.count", admin_table_path("departments"), text: "3"
  end

  # --- the rows of one table ----------------------------------------------------------------------------------------

  test "shows a table's columns and rows" do
    create(:employee, first_name: "Asha", last_name: "Verma", employee_number: "E00042")

    get admin_table_url("employees")

    assert_response :success
    assert_select "h1", /Employees/
    assert_select "th", text: /employee_number/
    assert_select "th", text: /salary_amount/
    assert_select "tbody tr", 1
    assert_select "tbody td", text: "E00042"
    assert_select "tbody td", text: "Asha"
  end

  test "text from the data is escaped, never run" do
    create(:department, name: %(<script>alert("x")</script>))

    get admin_table_url("departments")

    assert_not_includes response.body, %(<script>alert)
    assert_includes response.body, "&lt;script&gt;alert"
  end

  test "a yes-or-no column reads true or false" do
    create(:user, :admin, email: "boss@acme.example")

    get admin_table_url("users")

    assert_select "tbody td", text: "true"
  end

  test "a table that is empty says so" do
    get admin_table_url("departments")

    assert_response :success
    assert_select "tbody tr", 0
    assert_select ".empty", /No rows/
  end

  test "never shows a password digest" do
    user = create(:user)

    get admin_table_url("users")
    assert_not_includes response.body, user.password_digest
    assert_select "th", text: /password_digest/, count: 0

    get admin_record_url("users", user.id)
    assert_not_includes response.body, user.password_digest
    assert_not_includes response.body, "password_digest"
  end

  test "searches, and keeps the search in the links" do
    create(:department, name: "Engineering")
    create(:department, name: "Finance")

    get admin_table_url("departments", q: "eng")

    assert_select "tbody tr", 1
    assert_select "tbody td", text: "Engineering"
    assert_select "input[name=q][value=eng]"
    assert_select "th a[href*=?]", "q=eng"
  end

  test "pages, and says where you are" do
    create_list(:department, 30)

    get admin_table_url("departments", page: 2)

    assert_select "tbody tr", 5
    assert_select ".pager", /Page 2 of 2/
    assert_select ".pager", /30 rows/
    assert_select ".pager a[href*=?]", "page=1"
    assert_select ".pager a", text: /Next/, count: 0
  end

  test "sorts, and offers the opposite direction in the header link" do
    create(:department, name: "Bravo")
    create(:department, name: "Alpha")

    get admin_table_url("departments", sort: "name", direction: "asc")

    assert_equal %w[Alpha Bravo], css_select("tbody tr td:nth-child(2)").map { |cell| cell.text.strip }
    assert_select "th a[href*=?]", "direction=desc"
  end

  test "narrows to the rows of one related record" do
    first = create(:employee)
    second = create(:employee)
    create(:salary_change, employee: first, reason: "Belongs to first")
    create(:salary_change, employee: second, reason: "Belongs to second")

    get admin_table_url("salary_changes", filter: { employee_id: first.id })

    assert_select "tbody tr", 1
    assert_select "tbody td", text: "Belongs to first"
    assert_select ".filters", /employee_id/
  end

  test "a column that points at another table links to that record" do
    employee = create(:employee)

    get admin_table_url("employees")

    assert_select "tbody a[href=?]", admin_record_path("departments", employee.department_id)
    assert_select "tbody a[href=?]", admin_record_path("currencies", employee.currency_code)
  end

  test "an unknown table is a 404" do
    get admin_table_url("schema_migrations")

    assert_response :not_found
  end

  test "a page of rows costs the same number of queries however many rows there are" do
    create_list(:employee, 2)
    get admin_table_url("employees") # warm up
    few = count_queries { get admin_table_url("employees") }

    create_list(:employee, 20)
    many = count_queries { get admin_table_url("employees") }

    assert_equal few, many
  end

  # --- one record ---------------------------------------------------------------------------------------------------

  test "shows every column of a record" do
    employee = create(:employee, first_name: "Asha", salary_amount: 90_000)

    get admin_record_url("employees", employee.id)

    assert_response :success
    assert_select "h1", /Employees.*##{employee.id}/
    assert_select "dt", text: "first_name"
    assert_select "dd", text: "Asha"
    assert_select "dt", text: "salary_amount"
    assert_select "dd", text: "90000.00"
    assert_select "a[href=?]", admin_table_path("employees")
  end

  test "links a record to the ones it points at, and to the ones that point at it" do
    employee = create(:employee)
    create_list(:salary_change, 2, employee: employee)

    get admin_record_url("employees", employee.id)

    assert_select "dd a[href=?]", admin_record_path("countries", employee.country_id)
    assert_select ".related a[href=?]", admin_table_path("salary_changes", filter: { employee_id: employee.id }),
                  text: /salary_changes.*2/m
  end

  test "finds a record whose key is a code" do
    create(:currency, code: "QQQ", name: "Quux")

    get admin_record_url("currencies", "QQQ")

    assert_response :success
    assert_select "dd", text: "Quux"
  end

  test "a record that is not there is a 404" do
    get admin_record_url("departments", 999_999)

    assert_response :not_found
    assert_select "h1", /not found/i
  end
end
