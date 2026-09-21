require "test_helper"

class Admin::MetricsTest < ActiveSupport::TestCase
  include InsightsHelper

  test "counts what the system holds" do
    create(:employee)
    create(:employee, status: "inactive")
    create(:employee, status: "inactive")
    create(:department)
    create(:user, :admin)
    create(:session)

    counts = Admin::Metrics.call.counts

    assert_equal 3, counts[:employees]
    assert_equal 1, counts[:active_employees]
    assert_equal 2, counts[:inactive_employees]
    assert_equal Department.count, counts[:departments]
    assert_equal Country.count, counts[:countries]
    assert_equal JobTitle.count, counts[:job_titles]
    assert_equal 1, counts[:admins]
    assert_equal User.count, counts[:users]
    assert_equal 1, counts[:sessions]
    assert_equal 0, counts[:salary_changes]
  end

  test "only sessions that have not expired count as signed in" do
    create(:session)
    create(:session, created_at: 15.days.ago)

    assert_equal 1, Admin::Metrics.call.counts[:sessions]
  end

  test "the headline pay figures are those of the active employees, as the HR dashboard shows them" do
    paid(100_000)
    paid(200_000)
    paid(900_000, status: "inactive")

    overview = Admin::Metrics.call.overview

    assert_equal 2, overview[:headcount]
    assert_equal 300_000, overview[:payroll_usd]
    assert_equal 150_000, overview[:average_salary_usd]
  end

  test "headcount by department counts everyone, biggest first, and leaves out an empty department" do
    engineering = create(:department, name: "Engineering")
    operations = create(:department, name: "Operations")
    create(:department, name: "Nobody here")
    create_list(:employee, 2, department: engineering)
    create(:employee, department: operations, status: "inactive")

    assert_equal [ { label: "Engineering", value: 2 }, { label: "Operations", value: 1 } ],
                 Admin::Metrics.call.headcount_by_department
  end

  test "headcount by country shows the ten biggest" do
    12.times { |index| create_list(:employee, index + 1, country: create(:country, name: format("Land %02d", index))) }

    rows = Admin::Metrics.call.headcount_by_country

    assert_equal 10, rows.size
    assert_equal [ 12, 11, 10, 9, 8, 7, 6, 5, 4, 3 ], rows.pluck(:value)
    assert_equal "Land 11", rows.first[:label]
  end

  test "hires by year run from the first year to the last with no gap" do
    create(:employee, hire_date: Date.new(2020, 5, 1))
    create(:employee, hire_date: Date.new(2020, 11, 30))
    create(:employee, hire_date: Date.new(2023, 1, 2))

    assert_equal [ { label: "2020", value: 2 }, { label: "2021", value: 0 }, { label: "2022", value: 0 },
                   { label: "2023", value: 1 } ], Admin::Metrics.call.hires_by_year
  end

  test "salary changes by month cover the last twelve months, including the quiet ones" do
    travel_to Date.new(2026, 9, 21) do
      employee = create(:employee)
      [ "2026-09-05", "2026-09-20", "2026-07-01", "2025-10-01", "2025-09-30" ].each do |day|
        create(:salary_change, employee: employee, effective_on: Date.parse(day))
      end

      months = Admin::Metrics.call.salary_changes_by_month

      assert_equal 12, months.size
      assert_equal "2025-10", months.first[:label]
      assert_equal "2026-09", months.last[:label]
      assert_equal 1, months.first[:value]
      assert_equal 2, months.last[:value]
      assert_equal 1, months.find { |month| month[:label] == "2026-07" }[:value]
      assert_equal 0, months.find { |month| month[:label] == "2026-08" }[:value]
      assert_equal 4, months.sum { |month| month[:value] }, "a change before the window must not be counted"
    end
  end

  test "the status split is active against inactive" do
    create_list(:employee, 2)
    create(:employee, status: "inactive")

    assert_equal [ { label: "Active", value: 2 }, { label: "Inactive", value: 1 } ], Admin::Metrics.call.status_split
  end

  test "the salary distribution is the HR histogram in ten buckets with short labels" do
    paid(50_000)
    paid(150_000)
    paid(250_000)

    rows = Admin::Metrics.call.salary_distribution

    assert_equal 10, rows.size
    assert_equal 3, rows.sum { |row| row[:value] }
    assert_equal "50k–70k", rows.first[:label]
  end

  test "an empty system gives empty charts, not errors" do
    metrics = Admin::Metrics.call

    assert_equal 0, metrics.counts[:employees]
    assert_equal [], metrics.headcount_by_department
    assert_equal [], metrics.headcount_by_country
    assert_equal [], metrics.hires_by_year
    assert_equal [], metrics.salary_distribution
    assert_equal 12, metrics.salary_changes_by_month.size
    assert_equal [ 0, 0 ], metrics.status_split.pluck(:value)
  end
end
