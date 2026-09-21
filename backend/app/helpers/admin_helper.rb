# Presentation of raw table data in the admin panel. Everything returned is either plain text (escaped by the view) or
# built with Rails' own tag helpers, which escape their content, so data can never inject markup.
module AdminHelper
  LIST_TEXT_LIMIT = 80

  # One cell. A key of another listed table links to that row; on a list long text is cut short, on a record it is not.
  def cell_value(table, column, value, full: false)
    return tag.span("null", class: "null") if value.nil?

    target = table.links[column]
    return link_to(value, admin_record_path(target, value)) if target

    text = format_value(table, column, value)
    full ? text : truncate(text, length: LIST_TEXT_LIMIT)
  end

  # A header that sorts by the column, or reverses the sort if it is already the one in use.
  def sort_link(table, column)
    current = params[:sort] == column
    direction = current && params[:direction] != "desc" ? "desc" : "asc"
    marker = current ? (params[:direction] == "desc" ? " ▼" : " ▲") : ""

    link_to "#{column}#{marker}", table_path_with(table, "sort" => column, "direction" => direction, "page" => nil)
  end

  # The current list's address with some of its parameters changed; nil removes one.
  def table_path_with(table, changes = {})
    admin_table_path(table.name, request.query_parameters.merge(changes).compact)
  end

  # A whole-number USD figure with thousands separators, or a dash where there is nothing to average.
  def usd_figure(amount)
    amount.nil? ? "\u2014" : number_with_precision(amount, precision: 0, delimiter: ",")
  end

  def row_count(total)
    "#{number_with_delimiter(total)} #{'row'.pluralize(total)}"
  end

  private

  def format_value(table, column, value)
    case value
    when BigDecimal then number_with_precision(value, precision: table.model.columns_hash[column].scale || 0)
    when Time, ActiveSupport::TimeWithZone then value.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
    else value.to_s
    end
  end
end
