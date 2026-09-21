require "test_helper"

class Insights::OverviewTest < ActiveSupport::TestCase
  include InsightsHelper

  test "counts active employees only" do
    paid(50_000)
    paid(60_000)
    paid(70_000, status: :inactive)

    assert_equal 2, Insights::Overview.call[:headcount]
  end

  test "totals annual payroll in USD across currencies" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    india = create(:country, currency: inr)
    paid(100_000)
    create(:employee, country: india, salary_amount: 5_000_000) # 60,000 USD

    assert_equal 160_000, Insights::Overview.call[:payroll_usd]
  end

  test "leaves inactive employees out of payroll" do
    paid(100_000)
    paid(900_000, status: :inactive)

    assert_equal 100_000, Insights::Overview.call[:payroll_usd]
  end

  test "reports the average and the median salary" do
    [ 10_000, 20_000, 30_000, 100_000 ].each { |amount| paid(amount) }

    overview = Insights::Overview.call

    assert_equal 40_000, overview[:average_salary_usd]
    assert_equal 25_000, overview[:median_salary_usd] # the middle two are averaged
  end

  test "counts the countries and departments people are working in" do
    paid(50_000, department: create(:department))
    paid(50_000, department: create(:department))
    paid(50_000, country: create(:country), department: create(:department, name: "Only inactive"), status: :inactive)

    overview = Insights::Overview.call

    assert_equal 1, overview[:countries]
    assert_equal 2, overview[:departments]
  end

  test "reports the date of the oldest exchange rate behind the USD figures" do
    old = create(:currency, code: "INR", rate_to_usd: "0.012", rate_as_of: Date.new(2025, 12, 1))
    create(:currency, code: "EUR", rate_to_usd: "1.08", rate_as_of: Date.new(2020, 1, 1)) # unused, ignored
    paid(50_000)
    create(:employee, country: create(:country, currency: old), salary_amount: 1_000_000)

    assert_equal Date.new(2025, 12, 1), Insights::Overview.call[:rates_as_of]
  end

  test "is safe with no employees" do
    overview = Insights::Overview.call

    assert_equal 0, overview[:headcount]
    assert_equal 0, overview[:payroll_usd]
    assert_nil overview[:average_salary_usd]
    assert_nil overview[:median_salary_usd]
    assert_nil overview[:rates_as_of]
  end
end
