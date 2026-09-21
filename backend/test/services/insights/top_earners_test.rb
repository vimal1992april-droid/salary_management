require "test_helper"

class Insights::TopEarnersTest < ActiveSupport::TestCase
  include InsightsHelper

  test "returns the highest paid active employees first" do
    low = paid(50_000)
    high = paid(150_000)
    mid = paid(90_000)
    paid(900_000, status: :inactive)

    assert_equal [ high, mid, low ], Insights::TopEarners.call.to_a
  end

  test "can return the lowest paid first" do
    low = paid(50_000)
    high = paid(150_000)

    assert_equal [ low, high ], Insights::TopEarners.call(direction: "asc").to_a
  end

  test "ranks by USD value, so different currencies compare fairly" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    rupees = create(:employee, country: create(:country, currency: inr), salary_amount: 5_000_000) # 60,000 USD
    dollars = paid(70_000)

    assert_equal [ dollars, rupees ], Insights::TopEarners.call.to_a
  end

  test "limits the list, defaulting to 10 and never returning more than 50" do
    create_list(:employee, 12)

    assert_equal 10, Insights::TopEarners.call.to_a.size
    assert_equal 3, Insights::TopEarners.call(limit: 3).to_a.size
    assert_equal 12, Insights::TopEarners.call(limit: 500).to_a.size
    assert_equal 1, Insights::TopEarners.call(limit: 0).to_a.size
    assert_equal 10, Insights::TopEarners.call(limit: "lots").to_a.size
  end

  test "breaks ties by id" do
    tied = Array.new(3) { paid(70_000) }

    assert_equal tied, Insights::TopEarners.call.to_a
  end

  test "rejects an unknown direction" do
    assert_raises(Insights::InvalidParameter) { Insights::TopEarners.call(direction: "sideways") }
  end

  test "preloads what the serializer needs, so the list costs a constant number of queries" do
    render = ->(records) { records.each { |e| [ e.country.name, e.department.name, e.job_title.name, e.currency.rate_to_usd ] } }

    create_list(:employee, 2)
    few = count_queries { render.call(Insights::TopEarners.call) }
    create_list(:employee, 8)
    many = count_queries { render.call(Insights::TopEarners.call) }

    assert_equal few, many
  end
end
