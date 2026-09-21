require "test_helper"

class Employees::SearchTest < ActiveSupport::TestCase
  def search(**options)
    Employees::Search.call(**options)
  end

  # --- defaults -------------------------------------------------------------

  test "returns every employee ordered by last name then first name when nothing is asked for" do
    zoya = create(:employee, first_name: "Zoya", last_name: "Khan")
    bela = create(:employee, first_name: "Bela", last_name: "Verma")
    asha = create(:employee, first_name: "Asha", last_name: "Verma")

    assert_equal [ zoya, asha, bela ], search.records.to_a
  end

  # --- filters --------------------------------------------------------------

  test "filters by country" do
    india = create(:country)
    in_india = create(:employee, country: india)
    create(:employee)

    assert_equal [ in_india ], search(country_id: india.id).records.to_a
  end

  test "filters by department" do
    sales = create(:department)
    in_sales = create(:employee, department: sales)
    create(:employee)

    assert_equal [ in_sales ], search(department_id: sales.id).records.to_a
  end

  test "filters by job title" do
    title = create(:job_title)
    holder = create(:employee, job_title: title)
    create(:employee)

    assert_equal [ holder ], search(job_title_id: title.id).records.to_a
  end

  test "filters by status" do
    create(:employee)
    inactive = create(:employee, status: :inactive)

    assert_equal [ inactive ], search(status: "inactive").records.to_a
  end

  test "combines filters with AND" do
    india = create(:country)
    sales = create(:department)
    match = create(:employee, country: india, department: sales)
    create(:employee, country: india)
    create(:employee, department: sales)

    assert_equal [ match ], search(country_id: india.id, department_id: sales.id).records.to_a
  end

  test "treats blank filters as not given" do
    employee = create(:employee)

    assert_equal [ employee ], search(country_id: "", department_id: "", job_title_id: "", status: "", q: "").records.to_a
  end

  test "rejects an unknown status" do
    assert_raises(Employees::Search::InvalidParameter) { search(status: "retired") }
  end

  # --- text search ----------------------------------------------------------

  test "q matches first name, last name, email or employee number, ignoring case" do
    by_first = create(:employee, first_name: "Priyanka", last_name: "Zed")
    by_last = create(:employee, first_name: "Al", last_name: "Priyadarshi")
    by_email = create(:employee, email: "priya.nair@acme.example")
    by_number = create(:employee, employee_number: "PRIYA-7")
    create(:employee, first_name: "Someone", last_name: "Else")

    found = search(q: "PRIYA").records.to_a

    assert_equal [ by_first, by_last, by_email, by_number ].to_set, found.to_set
  end

  test "q with several words requires every word to match, in any field" do
    match = create(:employee, first_name: "Asha", last_name: "Verma")
    create(:employee, first_name: "Asha", last_name: "Khan")
    create(:employee, first_name: "Bela", last_name: "Verma")

    assert_equal [ match ], search(q: "asha verma").records.to_a
  end

  test "q treats % and _ as ordinary characters" do
    literal = create(:employee, first_name: "100%", last_name: "Real")
    create(:employee, first_name: "Everyone", last_name: "Else")

    assert_equal [ literal ], search(q: "%").records.to_a
  end

  # --- sorting --------------------------------------------------------------

  test "sorts by salary in USD, so different currencies compare fairly" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    usd = create(:currency, code: "USD", rate_to_usd: "1")
    india = create(:country, currency: inr)
    us = create(:country, currency: usd)
    rupees = create(:employee, country: india, salary_amount: 5_000_000) # about $60,000
    dollars = create(:employee, country: us, salary_amount: 70_000)

    assert_equal [ dollars, rupees ], search(sort: "salary", direction: "desc").records.to_a
    assert_equal [ rupees, dollars ], search(sort: "salary", direction: "asc").records.to_a
  end

  test "sorts by hire date" do
    newer = create(:employee, hire_date: Date.new(2024, 1, 1))
    older = create(:employee, hire_date: Date.new(2015, 1, 1))

    assert_equal [ older, newer ], search(sort: "hire_date", direction: "asc").records.to_a
  end

  test "sorts by country, department and job title name" do
    a, b = create(:employee), create(:employee)
    a.country.update!(name: "Zambia")
    b.country.update!(name: "Austria")
    a.department.update!(name: "Zoology")
    b.department.update!(name: "Accounts")
    a.job_title.update!(name: "Zookeeper")
    b.job_title.update!(name: "Auditor")

    assert_equal [ b, a ], search(sort: "country").records.to_a
    assert_equal [ b, a ], search(sort: "department").records.to_a
    assert_equal [ b, a ], search(sort: "job_title").records.to_a
    assert_equal [ a, b ], search(sort: "country", direction: "desc").records.to_a
  end

  test "breaks ties by id so pages never overlap" do
    same_pay = create_list(:employee, 3, salary_amount: 50_000)

    assert_equal same_pay.map(&:id), search(sort: "salary").records.map(&:id)
  end

  test "rejects an unknown sort or direction" do
    assert_raises(Employees::Search::InvalidParameter) { search(sort: "password_digest") }
    assert_raises(Employees::Search::InvalidParameter) { search(direction: "sideways") }
  end

  # --- pagination -----------------------------------------------------------

  test "pages through the results and reports the totals" do
    create_list(:employee, 5)

    page_two = search(per_page: 2, page: 2)

    assert_equal 2, page_two.records.size
    assert_equal({ page: 2, per_page: 2, total: 5, total_pages: 3 },
                 { page: page_two.page, per_page: page_two.per_page, total: page_two.total, total_pages: page_two.total_pages })
  end

  test "different pages contain different employees" do
    create_list(:employee, 5)

    first = search(per_page: 3, page: 1).records.map(&:id)
    second = search(per_page: 3, page: 2).records.map(&:id)

    assert_empty first & second
    assert_equal 5, (first + second).size
  end

  test "a page past the end is empty but still reports the total" do
    create_list(:employee, 2)

    result = search(per_page: 2, page: 9)

    assert_empty result.records
    assert_equal 2, result.total
  end

  test "caps the page size at 100 and falls back to sensible values for bad input" do
    assert_equal 100, search(per_page: 5_000).per_page
    assert_equal 1, search(per_page: 0).per_page
    assert_equal 25, search(per_page: "lots").per_page
    assert_equal 1, search(page: 0).page
    assert_equal 1, search(page: "abc").page
  end

  test "reports zero pages when there are no results" do
    assert_equal 0, search.total_pages
  end

  test "can return every match at once when pagination is turned off, as an export needs" do
    create_list(:employee, 7)
    create(:employee, status: :inactive)

    everything = search(status: "active", per_page: 2, paginate: false)

    assert_equal 7, everything.records.size
    assert_equal 7, everything.total
  end

  # --- performance ----------------------------------------------------------

  test "costs the same number of queries however many employees are on the page" do
    render = lambda do |result|
      result.records.each { |e| [ e.country.name, e.department.name, e.job_title.name, e.currency.rate_to_usd ] }
    end

    create_list(:employee, 3)
    few = count_queries { render.call(search) }
    create_list(:employee, 12)
    many = count_queries { render.call(search) }

    assert_equal few, many
  end
end
