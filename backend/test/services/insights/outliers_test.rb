require "test_helper"

class Insights::OutliersTest < ActiveSupport::TestCase
  include InsightsHelper

  setup do
    @engineer = create(:job_title, name: "Engineer")
  end

  # Ten peers earning 100k..109k. The quartiles are taken over the whole group, the outlier included:
  # with 140k added, Q1 = 102,500 and Q3 = 107,500, so the fences (Q1 - 1.5 IQR, Q3 + 1.5 IQR) are
  # 95,000 and 115,000, and the median is 105,000.
  def ten_peers(**attributes)
    (100_000..109_000).step(1_000).map { |amount| paid(amount, job_title: @engineer, **attributes) }
  end

  test "flags a salary above the upper fence of its peer group" do
    ten_peers
    high = paid(140_000, job_title: @engineer)

    outliers = Insights::Outliers.call

    assert_equal [ high ], outliers.map { |outlier| outlier[:employee] }
  end

  test "flags a salary below the lower fence" do
    ten_peers
    low = paid(60_000, job_title: @engineer)

    assert_equal [ low ], Insights::Outliers.call.map { |outlier| outlier[:employee] }
  end

  test "does not flag salaries inside the fences" do
    ten_peers
    paid(113_000, job_title: @engineer)
    paid(96_000, job_title: @engineer)

    assert_empty Insights::Outliers.call
  end

  test "describes how far outside the range the salary is, and what the peers earn" do
    ten_peers
    paid(140_000, job_title: @engineer)

    outlier = Insights::Outliers.call.first

    assert_equal "above", outlier[:direction]
    assert_equal 105_000, outlier[:peer_median]
    assert_equal [ 95_000, 115_000 ], outlier[:fences]
    assert_equal 11, outlier[:peer_count]
    assert_equal 140_000, outlier[:salary]
    assert_equal BigDecimal("0.24"), outlier[:deviation] # (140,000 - 115,000) / 105,000
  end

  test "compares people only with the same job title in the same country" do
    india = create(:country, name: "India", iso_code: "IN", currency: usd)
    ten_peers
    # 200k is a huge outlier among Engineers in the US, but the only Engineer in India: no peers to compare with.
    paid(200_000, job_title: @engineer, country: india)
    # A different title with the same pay is not compared with the engineers.
    paid(140_000, job_title: create(:job_title, name: "Director"))

    assert_empty Insights::Outliers.call
  end

  test "needs at least 5 peers before judging anyone" do
    4.times { |i| paid(100_000 + (i * 1_000), job_title: @engineer) }
    paid(400_000, job_title: @engineer)

    assert_equal 5, Employee.count
    assert_equal [ 400_000 ], Insights::Outliers.call.map { |outlier| outlier[:salary] }

    Employee.last.destroy!
    assert_empty Insights::Outliers.call
  end

  test "compares in local currency, so exchange rates play no part" do
    inr = create(:currency, code: "INR", rate_to_usd: "0.012")
    india = create(:country, currency: inr)
    10.times { |i| create(:employee, country: india, job_title: @engineer, salary_amount: 1_000_000 + (i * 10_000)) }
    high = create(:employee, country: india, job_title: @engineer, salary_amount: 2_000_000)

    outlier = Insights::Outliers.call.first

    assert_equal high, outlier[:employee]
    assert_equal "INR", outlier[:currency]
  end

  test "ignores inactive employees, both as outliers and as peers" do
    ten_peers
    paid(140_000, job_title: @engineer, status: :inactive)

    assert_empty Insights::Outliers.call
  end

  test "lists the biggest outliers first and honours the limit" do
    ten_peers
    paid(130_000, job_title: @engineer)
    biggest = paid(200_000, job_title: @engineer)

    assert_equal biggest, Insights::Outliers.call.first[:employee]
    assert_equal 1, Insights::Outliers.call(limit: 1).size
  end

  test "costs a constant number of queries" do
    ten_peers
    3.times { |i| paid(140_000 + i, job_title: @engineer) }
    few = count_queries { Insights::Outliers.call.each { |o| o[:employee].country.name } }

    other = create(:job_title, name: "Analyst")
    10.times { |i| paid(100_000 + (i * 1_000), job_title: other) }
    3.times { |i| paid(180_000 + i, job_title: other) }
    many = count_queries { Insights::Outliers.call.each { |o| o[:employee].country.name } }

    assert_equal few, many
  end
end
