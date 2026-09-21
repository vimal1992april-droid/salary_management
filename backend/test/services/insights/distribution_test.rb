require "test_helper"

class Insights::DistributionTest < ActiveSupport::TestCase
  include InsightsHelper

  def distribution(**options)
    Insights::Distribution.call(**options)
  end

  def counts(result)
    result[:buckets].map { |bucket| bucket[:count] }
  end

  test "splits the USD salary range into equal buckets and counts employees in each" do
    [ 100, 150, 200, 300, 400 ].each { |amount| paid(amount) }

    result = distribution(bucket_count: 3)

    assert_equal [ 100, 400 ], [ result[:min], result[:max] ]
    assert_equal [ [ 100, 200, 2 ], [ 200, 300, 1 ], [ 300, 400, 2 ] ],
                 result[:buckets].map { |bucket| [ bucket[:from], bucket[:to], bucket[:count] ] }
  end

  test "puts the highest salary in the last bucket rather than an extra one" do
    [ 100, 400 ].each { |amount| paid(amount) }

    assert_equal [ 1, 0, 1 ], counts(distribution(bucket_count: 3))
  end

  test "includes empty buckets so the chart has no gaps" do
    [ 0.01, 100, 1_000 ].each { |amount| paid(amount) }

    assert_equal [ 2, 0, 0, 0, 1 ], counts(distribution(bucket_count: 5))
  end

  test "counts active employees only" do
    paid(100)
    paid(400)
    paid(9_999, status: :inactive)

    assert_equal 400, distribution(bucket_count: 2)[:max]
  end

  test "converts salaries to USD" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    paid(100)
    create(:employee, country: create(:country, currency: inr), salary_amount: 50_000) # 600 USD

    assert_equal 600, distribution(bucket_count: 2)[:max]
  end

  test "is a single bucket when everyone earns the same" do
    3.times { paid(50_000) }

    result = distribution(bucket_count: 10)

    assert_equal [ { from: 50_000, to: 50_000, count: 3 } ], result[:buckets]
  end

  test "narrows the population with filters" do
    india = create(:country, name: "India", iso_code: "IN", currency: usd)
    paid(100, country: india)
    paid(300, country: india)
    paid(99_999)

    assert_equal 300, distribution(bucket_count: 2, country_id: india.id)[:max]
  end

  test "defaults to 10 buckets and keeps the count between 1 and 50" do
    [ 100, 200 ].each { |amount| paid(amount) }

    assert_equal 10, distribution[:buckets].size
    assert_equal 1, distribution(bucket_count: 0)[:buckets].size
    assert_equal 50, distribution(bucket_count: 500)[:buckets].size
    assert_equal 10, distribution(bucket_count: "many")[:buckets].size
  end

  test "is empty with no employees" do
    assert_equal({ min: nil, max: nil, buckets: [] }, distribution)
  end
end
