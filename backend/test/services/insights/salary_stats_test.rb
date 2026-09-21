require "test_helper"

class Insights::SalaryStatsTest < ActiveSupport::TestCase
  include InsightsHelper

  def stats(**options)
    Insights::SalaryStats.call(**options)
  end

  def row_for(rows, name)
    rows.find { |row| row[:group][:name] == name }
  end

  test "computes headcount, range, quartiles, median and mean for each group" do
    engineering = create(:department, name: "Engineering")
    [ 10_000, 20_000, 30_000, 40_000, 50_000 ].each { |amount| paid(amount, department: engineering) }

    row = row_for(stats(group_by: "department"), "Engineering")

    assert_equal(
      { headcount: 5, min: 10_000, p25: 20_000, median: 30_000, p75: 40_000, max: 50_000, mean: 30_000 },
      row.except(:group)
    )
    assert_equal engineering.id, row[:group][:id]
  end

  test "interpolates between values, as percentile_cont does" do
    sales = create(:department, name: "Sales")
    [ 10_000, 20_000, 30_000, 100_000 ].each { |amount| paid(amount, department: sales) }

    row = row_for(stats(group_by: "department"), "Sales")

    assert_equal 17_500, row[:p25]
    assert_equal 25_000, row[:median]
    assert_equal 47_500, row[:p75]
  end

  test "a group of one has the same value everywhere" do
    only = create(:department, name: "Legal")
    paid(80_000, department: only)

    row = row_for(stats(group_by: "department"), "Legal")

    assert_equal [ 1, 80_000, 80_000, 80_000, 80_000, 80_000, 80_000 ],
                 row.values_at(:headcount, :min, :p25, :median, :p75, :max, :mean)
  end

  test "converts every salary to USD before comparing" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    team = create(:department, name: "Global")
    paid(70_000, department: team)
    create(:employee, country: create(:country, currency: inr), department: team, salary_amount: 5_000_000) # 60,000 USD

    row = row_for(stats(group_by: "department"), "Global")

    assert_equal [ 60_000, 70_000, 65_000 ], row.values_at(:min, :max, :median)
  end

  test "counts active employees only, and lists only groups that have some" do
    staffed = create(:department, name: "Staffed")
    empty = create(:department, name: "Only ex-employees")
    paid(50_000, department: staffed)
    paid(90_000, department: staffed, status: :inactive)
    paid(70_000, department: empty, status: :inactive)

    rows = stats(group_by: "department")

    assert_equal [ "Staffed" ], rows.map { |row| row[:group][:name] }
    assert_equal [ 1, 50_000 ], row_for(rows, "Staffed").values_at(:headcount, :max)
  end

  test "groups by country and by job title" do
    india = create(:country, name: "India", iso_code: "IN", currency: usd)
    engineer = create(:job_title, name: "Engineer")
    paid(10_000, country: india, job_title: engineer)
    paid(30_000, job_title: engineer)

    assert_equal [ "India", "United States" ], stats(group_by: "country").map { |row| row[:group][:name] }
    assert_equal [ 2, 20_000 ], row_for(stats(group_by: "job_title"), "Engineer").values_at(:headcount, :mean)
  end

  test "orders groups by name" do
    %w[Zulu Alpha Mike].each { |name| paid(50_000, department: create(:department, name:)) }

    assert_equal %w[Alpha Mike Zulu], stats(group_by: "department").map { |row| row[:group][:name] }
  end

  test "narrows the population with filters, so job titles can be compared within one country" do
    india = create(:country, name: "India", iso_code: "IN", currency: usd)
    engineer = create(:job_title, name: "Engineer")
    paid(10_000, country: india, job_title: engineer)
    paid(90_000, job_title: engineer)

    row = row_for(stats(group_by: "job_title", country_id: india.id), "Engineer")

    assert_equal [ 1, 10_000 ], row.values_at(:headcount, :max)
    assert_empty stats(group_by: "job_title", country_id: create(:country).id)
  end

  test "is empty with no employees" do
    assert_empty stats(group_by: "country")
  end

  test "rejects an unknown or missing grouping" do
    assert_raises(Insights::InvalidParameter) { stats(group_by: "salary") }
    assert_raises(Insights::InvalidParameter) { stats(group_by: nil) }
  end
end
