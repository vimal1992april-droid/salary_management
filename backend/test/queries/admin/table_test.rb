require "test_helper"

class Admin::TableTest < ActiveSupport::TestCase
  test "lists every table the system keeps, by name" do
    names = Admin::Table.all.map(&:name)

    assert_equal %w[employees salary_changes departments job_titles countries currencies users sessions], names
  end

  test "finds a table by name and refuses one that is not listed" do
    assert_equal Employee, Admin::Table.find!("employees").model
    assert_raises(ActiveRecord::RecordNotFound) { Admin::Table.find!("schema_migrations") }
    assert_raises(ActiveRecord::RecordNotFound) { Admin::Table.find!("employees; drop table users") }
  end

  test "has a readable title and a row count" do
    create_list(:department, 3)

    table = Admin::Table.find!("departments")

    assert_equal "Departments", table.title
    assert_equal 3, table.count
    assert_equal "Job titles", Admin::Table.find!("job_titles").title
  end

  test "shows the columns in database order" do
    assert_equal %w[id name created_at updated_at], Admin::Table.find!("departments").columns
  end

  test "never exposes a password digest" do
    user = create(:user)
    table = Admin::Table.find!("users")

    assert_not_includes table.columns, "password_digest"
    assert_not_includes table.attributes_of(user).keys, "password_digest"
  end

  test "knows which columns point at another table" do
    assert_equal({ "country_id" => "countries", "department_id" => "departments", "job_title_id" => "job_titles",
                   "currency_code" => "currencies" }, Admin::Table.find!("employees").links)
    assert_equal({ "employee_id" => "employees", "changed_by_id" => "users", "new_currency_code" => "currencies",
                   "previous_currency_code" => "currencies" }, Admin::Table.find!("salary_changes").links)
  end

  # --- paging ---------------------------------------------------------------------------------------------------

  test "pages through the rows 25 at a time by default" do
    create_list(:department, 30)
    table = Admin::Table.find!("departments")

    first = table.page
    second = table.page(page: 2)

    assert_equal 25, first.records.size
    assert_equal 5, second.records.size
    assert_equal [ 30, 2, 25 ], [ first.total, first.total_pages, first.per_page ]
    assert_equal 2, second.page
  end

  test "a page size is capped and a nonsense one falls back to the default" do
    table = Admin::Table.find!("departments")

    assert_equal 100, table.page(per_page: "5000").per_page
    assert_equal 50, table.page(per_page: "50").per_page
    assert_equal 25, table.page(per_page: "abc").per_page
    assert_equal 25, table.page(per_page: "-3").per_page
  end

  test "a page number below one is the first page" do
    create_list(:department, 2)

    assert_equal 1, Admin::Table.find!("departments").page(page: "-4").page
    assert_equal 1, Admin::Table.find!("departments").page(page: "x").page
  end

  test "an empty table has one empty page" do
    result = Admin::Table.find!("departments").page

    assert_equal [], result.records.to_a
    assert_equal [ 0, 1 ], [ result.total, result.total_pages ]
  end

  # --- searching ------------------------------------------------------------------------------------------------

  test "searches every text column, ignoring case" do
    create(:employee, first_name: "Asha", last_name: "Verma", email: "one@acme.example")
    create(:employee, first_name: "Ravi", last_name: "Kumar", email: "asha.fan@acme.example")
    create(:employee, first_name: "Meena", last_name: "Iyer", email: "three@acme.example")

    result = Admin::Table.find!("employees").page(q: "ASHA")

    assert_equal %w[one@acme.example asha.fan@acme.example].sort, result.records.map(&:email).sort
    assert_equal 2, result.total
  end

  test "a wildcard typed into the search is an ordinary character" do
    create(:department, name: "100% Remote")
    create(:department, name: "Plain")

    assert_equal [ "100% Remote" ], Admin::Table.find!("departments").page(q: "%").records.map(&:name)
    assert_equal [], Admin::Table.find!("departments").page(q: "_").records.to_a
  end

  test "a number also finds the row with that id" do
    target = create(:department, name: "Target")
    create(:department, name: "Other")

    assert_equal [ target ], Admin::Table.find!("departments").page(q: target.id.to_s).records.to_a
  end

  test "does not search the password digest" do
    user = create(:user, email: "hr@acme.example")
    digest_piece = user.password_digest[7, 12]

    assert_equal 0, Admin::Table.find!("users").page(q: digest_piece).total
  end

  # --- sorting --------------------------------------------------------------------------------------------------

  test "sorts by a column in either direction, and by id when none is given" do
    create(:department, name: "Bravo")
    create(:department, name: "Alpha")
    create(:department, name: "Charlie")
    table = Admin::Table.find!("departments")

    assert_equal %w[Alpha Bravo Charlie], table.page(sort: "name", direction: "asc").records.map(&:name)
    assert_equal %w[Charlie Bravo Alpha], table.page(sort: "name", direction: "desc").records.map(&:name)
    assert_equal %w[Bravo Alpha Charlie], table.page.records.map(&:name)
  end

  test "a sort on something that is not a visible column is ignored" do
    create(:user)
    table = Admin::Table.find!("users")

    assert_equal 1, table.page(sort: "password_digest").total
    assert_equal 1, table.page(sort: "id; drop table users", direction: "sideways").total
  end

  # --- filtering ------------------------------------------------------------------------------------------------

  test "narrows to the rows that match a column, and ignores a column that is not there" do
    first = create(:employee)
    second = create(:employee)
    change = create(:salary_change, employee: first)
    create(:salary_change, employee: second)
    table = Admin::Table.find!("salary_changes")

    assert_equal [ change ], table.page(filters: { "employee_id" => first.id.to_s }).records.to_a
    assert_equal 2, table.page(filters: { "nonsense" => "1" }).total
    assert_equal 2, table.page(filters: { "employee_id" => "" }).total
  end

  # --- one record -------------------------------------------------------------------------------------------------

  test "finds one record by its primary key, even when the key is a code" do
    currency = create(:currency, code: "QQQ")

    assert_equal currency, Admin::Table.find!("currencies").find_record("QQQ")
    assert_raises(ActiveRecord::RecordNotFound) { Admin::Table.find!("currencies").find_record("ZZZ") }
  end

  test "counts the records that belong to a record, for the tables that have them" do
    employee = create(:employee)
    create_list(:salary_change, 2, employee: employee)

    related = Admin::Table.find!("employees").related_counts(employee)

    assert_equal [ { table: "salary_changes", column: "employee_id", count: 2 } ], related
  end

  test "a table nothing points at has no related counts" do
    assert_equal [], Admin::Table.find!("sessions").related_counts(create(:session))
  end
end
