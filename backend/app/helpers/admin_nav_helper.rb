# The sidebar: which links there are and which one is the page you are on.
module AdminNavHelper
  # One link of the sidebar. The current page is marked for assistive technology (aria-current) and for the eye (CSS
  # styles that attribute), so the two cannot disagree.
  def sidebar_link(label, path, icon:, current: false)
    link_to path, class: "nav-link", "aria-current": (current ? "page" : nil) do
      safe_join([ admin_icon(icon), tag.span(label) ])
    end
  end

  def on_dashboard?
    controller_path == "admin/dashboard"
  end

  def on_table_list?
    controller_path == "admin/tables" && action_name == "index"
  end

  # A table's rows, or one of its records.
  def on_table?(name)
    %w[admin/tables admin/records].include?(controller_path) && action_name != "index" && params[:table] == name
  end

  def on_api_monitor?
    controller_path == "admin/api_monitor"
  end

  def on_api_requests?
    controller_path == "admin/api_requests"
  end

  # The signed-in administrator's initial, for the round badge beside their address.
  def initial_of(email)
    email.to_s.first.to_s.upcase
  end
end
