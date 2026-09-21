# Charts drawn on the server as inline SVG, so the admin panel needs no JavaScript library. Each takes rows of
# { label:, value: } and a title, and returns a captioned <figure> holding an image that is described for screen
# readers. All text goes through Rails' tag helpers, so labels from the data are escaped.
module AdminChartHelper
  PALETTE = %w[#2563eb #7c3aed #0891b2 #16a34a #d97706 #dc2626 #db2777 #4b5563].freeze

  BAR = { width: 640, label_width: 170, max_bar: 400, row: 28, bar_height: 18, label_limit: 24 }.freeze
  COLUMN = { width: 640, height: 260, left: 44, right: 10, top: 20, bottom: 44, fill: 0.7, max_labels: 12 }.freeze
  DONUT = { size: 160, radius: 60, stroke: 28 }.freeze

  # Horizontal bars, one row each: for categories with long names (departments, countries).
  def bar_chart(rows, title:)
    return no_data(title) if rows.empty?

    max = rows.pluck(:value).max
    height = rows.size * BAR[:row] + 8
    marks = rows.each_with_index.flat_map do |row, index|
      y = 4 + index * BAR[:row]
      width = scaled(row[:value], max, BAR[:max_bar])
      [ tag.text(truncate(row[:label].to_s, length: BAR[:label_limit]), class: "label", x: BAR[:label_width] - 8, y: y + 14,
                                                                        "text-anchor": "end"),
        tag.rect(class: "bar", x: BAR[:label_width], y: y, width: width, height: BAR[:bar_height], rx: 3) { tag.title(tooltip(row)) },
        tag.text(number_with_delimiter(row[:value]), class: "value", x: BAR[:label_width] + width + 6, y: y + 14) ]
    end

    figure(title, svg(title, BAR[:width], height, marks))
  end

  # Vertical columns along a baseline: for a series in order (years, months, salary bands).
  def column_chart(rows, title:)
    return no_data(title) if rows.empty?

    max = rows.pluck(:value).max
    plot_width = COLUMN[:width] - COLUMN[:left] - COLUMN[:right]
    plot_height = COLUMN[:height] - COLUMN[:top] - COLUMN[:bottom]
    slot = plot_width.to_f / rows.size
    label_every = (rows.size.to_f / COLUMN[:max_labels]).ceil
    baseline = COLUMN[:top] + plot_height

    marks = [ tag.text(number_with_delimiter(max), class: "axis", x: COLUMN[:left] - 6, y: COLUMN[:top] + 4, "text-anchor": "end"),
              tag.line(class: "baseline", x1: COLUMN[:left], y1: baseline, x2: COLUMN[:width] - COLUMN[:right], y2: baseline) ]
    rows.each_with_index do |row, index|
      column_width = slot * COLUMN[:fill]
      x = COLUMN[:left] + slot * index + (slot - column_width) / 2
      height = scaled(row[:value], max, plot_height)

      marks << tag.rect(class: "column", x: x.round(2), y: (baseline - height).round(2), width: column_width.round(2),
                        height: height) { tag.title(tooltip(row)) }
      if rows.size <= COLUMN[:max_labels] && row[:value].positive?
        marks << tag.text(number_with_delimiter(row[:value]), class: "value", x: (x + column_width / 2).round(2),
                                                              y: (baseline - height - 4).round(2), "text-anchor": "middle")
      end
      next unless (index % label_every).zero?

      marks << tag.text(row[:label].to_s, class: "label", x: (x + column_width / 2).round(2), y: baseline + 16, "text-anchor": "middle")
    end

    figure(title, svg(title, COLUMN[:width], COLUMN[:height], marks))
  end

  # A ring divided in proportion, with a legend that gives each share: for a few parts of a whole.
  def donut_chart(rows, title:)
    total = rows.sum { |row| row[:value] }
    return no_data(title) if total.zero?

    circumference = 2 * Math::PI * DONUT[:radius]
    centre = DONUT[:size] / 2
    offset = 0.0
    slices = rows.each_with_index.filter_map do |row, index|
      length = row[:value].to_f / total * circumference
      slice = tag.circle(class: "slice", cx: centre, cy: centre, r: DONUT[:radius], fill: "none", stroke: color(index),
                         "stroke-width": DONUT[:stroke], "stroke-dasharray": "#{length.round(2)} #{(circumference - length).round(2)}",
                         "stroke-dashoffset": (-offset).round(2), transform: "rotate(-90 #{centre} #{centre})") { tag.title(tooltip(row)) }
      offset += length
      slice unless row[:value].zero?
    end
    slices << tag.text(number_with_delimiter(total), class: "total", x: centre, y: centre + 6, "text-anchor": "middle")

    legend = tag.ul(class: "legend") do
      safe_join(rows.each_with_index.map do |row, index|
        tag.li(safe_join([ tag.span("", class: "swatch", style: "background: #{color(index)}"),
                           " #{row[:label]} #{number_with_delimiter(row[:value])} (#{(row[:value] * 100.0 / total).round}%)" ]))
      end)
    end

    figure(title, tag.div(safe_join([ svg(title, DONUT[:size], DONUT[:size], slices), legend ]), class: "donut"))
  end

  private

  def figure(title, body)
    tag.figure(safe_join([ tag.figcaption(title), body ]), class: "chart")
  end

  def svg(title, width, height, marks)
    tag.svg(safe_join(marks), class: "chart", role: "img", "aria-label": title, viewBox: "0 0 #{width} #{height}")
  end

  def no_data(title)
    figure(title, tag.p("No data yet", class: "no-data"))
  end

  def scaled(value, max, size)
    max.zero? ? 0 : (value.to_f / max * size).round(2)
  end

  def tooltip(row)
    "#{row[:label]}: #{number_with_delimiter(row[:value])}"
  end

  def color(index)
    PALETTE[index % PALETTE.size]
  end
end
