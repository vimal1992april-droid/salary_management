require "test_helper"

class AdminChartHelperTest < ActionView::TestCase
  include AdminChartHelper

  ROWS = [ { label: "Engineering", value: 200 }, { label: "Sales", value: 100 }, { label: "HR", value: 0 } ].freeze

  def dom(html)
    Nokogiri::HTML.fragment(html)
  end

  # --- bars -------------------------------------------------------------------------------------------------------

  test "a bar chart draws one bar per row, the longest for the biggest value" do
    chart = dom(bar_chart(ROWS, title: "Headcount by department"))

    bars = chart.css("rect.bar")
    assert_equal 3, bars.size
    widths = bars.map { |bar| bar["width"].to_f }
    assert_equal widths[0] / 2, widths[1]
    assert_equal 0, widths[2]
    assert_operator widths[0], :>, 0
  end

  test "a chart is a described image with a caption, a label and a value for every row" do
    chart = dom(bar_chart(ROWS, title: "Headcount by department"))

    assert_equal "Headcount by department", chart.at_css("figcaption").text
    assert_equal "img", chart.at_css("svg.chart")["role"]
    assert_equal "Headcount by department", chart.at_css("svg.chart")["aria-label"]
    assert_equal %w[Engineering Sales HR], chart.css("text.label").map(&:text)
    assert_equal %w[200 100 0], chart.css("text.value").map(&:text)
    assert_equal "Engineering: 200", chart.at_css("rect.bar title").text
  end

  test "big numbers get thousands separators" do
    chart = dom(bar_chart([ { label: "Big", value: 1_234_567 } ], title: "x"))

    assert_equal "1,234,567", chart.at_css("text.value").text
  end

  test "labels and titles are escaped, never markup" do
    html = bar_chart([ { label: "<img src=x onerror=alert(1)>", value: 5 } ], title: "<script>bad()</script>")

    assert_not_includes html, "<img"
    assert_not_includes html, "<script>"
    assert_includes html, "&lt;img"
  end

  test "a chart with nothing to show says so instead of drawing" do
    [ bar_chart([], title: "Empty"), column_chart([], title: "Empty"), donut_chart([], title: "Empty") ].each do |html|
      chart = dom(html)

      assert_equal "Empty", chart.at_css("figcaption").text
      assert_match(/No data/, chart.text)
      assert_nil chart.at_css("svg")
    end
  end

  test "rows that are all zero draw without dividing by zero" do
    chart = dom(bar_chart([ { label: "A", value: 0 }, { label: "B", value: 0 } ], title: "Zeros"))

    assert_equal [ 0.0, 0.0 ], chart.css("rect.bar").map { |bar| bar["width"].to_f }
  end

  # --- columns ----------------------------------------------------------------------------------------------------

  test "a column chart draws one column per row, the tallest for the biggest value" do
    chart = dom(column_chart(ROWS, title: "Hires"))

    columns = chart.css("rect.column")
    assert_equal 3, columns.size
    heights = columns.map { |column| column["height"].to_f }
    assert_equal heights[0] / 2, heights[1]
    assert_equal 0, heights[2]
    assert_equal %w[Engineering Sales HR], chart.css("text.label").map(&:text)
    assert_equal "Sales: 100", columns[1].at_css("title").text
  end

  test "a column chart with many rows labels only some of them so the labels stay readable" do
    rows = Array.new(24) { |index| { label: "M#{index}", value: index } }

    chart = dom(column_chart(rows, title: "Many"))

    assert_equal 24, chart.css("rect.column").size
    assert_operator chart.css("text.label").size, :<, 24
  end

  test "a column chart thins out labels that are wider than the space between columns" do
    rows = Array.new(10) { |index| { label: "#{100 + index}k–#{144 + index}k", value: index + 1 } }

    chart = dom(column_chart(rows, title: "Salary bands"))

    labels = chart.css("text.label")
    assert_equal 10, chart.css("rect.column").size
    assert_operator labels.size, :<, 10
    assert_operator labels.size, :>=, 3
  end

  test "short labels are all shown when there is room" do
    rows = Array.new(10) { |index| { label: "Y#{index}", value: index + 1 } }

    assert_equal 10, dom(column_chart(rows, title: "Years")).css("text.label").size
  end

  # --- donut ------------------------------------------------------------------------------------------------------

  test "a donut splits the ring in proportion and lists each share" do
    chart = dom(donut_chart([ { label: "Active", value: 75 }, { label: "Inactive", value: 25 } ], title: "Status"))

    slices = chart.css("circle.slice")
    assert_equal 2, slices.size
    lengths = slices.map { |slice| slice["stroke-dasharray"].split.first.to_f }
    assert_in_delta lengths[0], lengths[1] * 3, 0.5
    legend = chart.css("li").map { |item| item.text.squish }
    assert_equal [ "Active 75 (75%)", "Inactive 25 (25%)" ], legend
  end

  test "a donut uses the colours it is given, so a status can look like what it means" do
    rows = [ { label: "OK", value: 3 }, { label: "Failed", value: 1 } ]

    chart = dom(donut_chart(rows, title: "Status", colors: %w[#16a34a #dc2626]))

    assert_equal %w[#16a34a #dc2626], chart.css("circle.slice").map { |slice| slice["stroke"] }
    assert_includes chart.css(".swatch").map { |swatch| swatch["style"] }.join, "#dc2626"
  end

  test "a donut whose values are all zero has nothing to show" do
    chart = dom(donut_chart([ { label: "Active", value: 0 }, { label: "Inactive", value: 0 } ], title: "Status"))

    assert_match(/No data/, chart.text)
  end
end
