require "test_helper"

# The frame around every admin page: what is in it, that it can be used without a mouse, and that it loads its
# styles, script and font from this app and nowhere else.
class AdminLayoutTest < ActionDispatch::IntegrationTest
  setup { sign_in_as_admin }

  # --- the frame -----------------------------------------------------------------------------------------------------

  test "every page is a proper document with a skip link, a sidebar, a top bar and one main area" do
    get admin_root_url

    assert_select "html[lang=en]"
    assert_select "a.skip-link[href='#main']", text: /Skip to content/
    assert_select "aside#sidebar[aria-label]"
    assert_select "header.topbar"
    assert_select "main#main", 1
    assert_select "meta[name=viewport]"
    assert_select "meta[name=robots][content*=noindex]"
  end

  test "the sidebar links to every page, and to every table" do
    get admin_root_url

    assert_select "#sidebar a[href=?]", admin_root_path, text: /Dashboard/
    assert_select "#sidebar a[href=?]", admin_tables_path, text: /All tables/
    Admin::Table.all.each do |table|
      assert_select "#sidebar a[href=?]", admin_table_path(table.name), text: table.title
    end
    assert_select "#sidebar a[href=?]", admin_api_monitor_path, text: /API monitor/
    assert_select "#sidebar a[href=?]", admin_api_requests_path, text: /Calls/
  end

  test "the sidebar groups its links under headings" do
    get admin_root_url

    assert_select "#sidebar .nav-heading", text: /Overview/
    assert_select "#sidebar .nav-heading", text: /Data/
    assert_select "#sidebar .nav-heading", text: /Monitoring/
  end

  test "the sidebar says who is signed in and signs them out with a plain form post" do
    admin = create(:user, :admin, email: "second-admin@acme.example")
    delete_session_and_sign_in(admin)

    get admin_root_url

    assert_select "#sidebar .account", text: /second-admin@acme.example/
    assert_select "#sidebar form[action=?][method=post]", admin_logout_path do
      assert_select "input[name=_method]", 0
      assert_select "button", text: /Sign out/
    end
  end

  test "the top bar names the environment" do
    get admin_root_url

    assert_select "header.topbar .env-badge", text: Rails.env
  end

  # --- which page you are on --------------------------------------------------------------------------------------------

  test "the sidebar marks the page you are on, and only that one" do
    employee = create(:employee)
    recorded = create(:api_request)

    {
      admin_root_url => admin_root_path,
      admin_tables_url => admin_tables_path,
      admin_table_url("employees") => admin_table_path("employees"),
      admin_record_url("employees", employee.id) => admin_table_path("employees"),
      admin_api_monitor_url => admin_api_monitor_path,
      admin_api_requests_url => admin_api_requests_path,
      admin_api_request_url(recorded) => admin_api_requests_path
    }.each do |url, current|
      get url

      assert_select "#sidebar a[aria-current=page]", 1, "#{url} should mark exactly one link"
      assert_select "#sidebar a[aria-current=page][href=?]", current
    end
  end

  # --- controls ---------------------------------------------------------------------------------------------------------------

  test "has a theme switch and a menu button that a script can drive and a screen reader can name" do
    get admin_root_url

    assert_select "header.topbar button[data-theme-toggle][aria-label][aria-pressed]"
    assert_select "header.topbar button[data-sidebar-toggle][aria-controls=sidebar][aria-expanded=false][aria-label]"
    assert_select "[data-sidebar-backdrop]"
  end

  test "every icon is decoration, hidden from screen readers" do
    get admin_root_url

    assert_select "svg.icon", minimum: 8
    assert_select "svg.icon:not([aria-hidden=true])", 0
  end

  # --- where it gets its styles, script and font -------------------------------------------------------------------------------

  test "loads a versioned stylesheet and script from this app" do
    get admin_root_url

    assert_select "link[rel=stylesheet][href^=?]", "/admin-assets/admin.css?v="
    assert_select "script[src^=?][defer]", "/admin-assets/admin.js?v="
  end

  test "has no inline stylesheet: the styles are one cacheable file" do
    get admin_root_url

    assert_select "style", 0
  end

  test "preloads the font so text does not jump when it arrives" do
    get admin_root_url

    assert_select "link[rel=preload][as=font][type='font/woff2'][crossorigin][href=?]",
                  "/admin-assets/fonts/montserrat-latin-wght-normal.woff2"
  end

  test "picks the saved theme before the page is drawn, so it does not flash" do
    get admin_root_url

    script = css_select("head script:not([src])").map(&:text).join
    assert_includes script, "localStorage"
    assert_includes script, "data-theme"
    assert_includes script, "prefers-color-scheme"
    assert_select "meta[name=color-scheme][content='light dark']"
  end

  test "asks nothing of any other site" do
    get admin_root_url

    external = css_select("[href], [src], [action]").map { |node| node["href"] || node["src"] || node["action"] }
                                                     .grep(%r{\A(https?:)?//})
    assert_empty external
  end

  # --- the sign-in page ---------------------------------------------------------------------------------------------------------

  test "the sign-in page has the same look but no sidebar" do
    post admin_logout_url

    get admin_login_url

    assert_select "link[rel=stylesheet][href^=?]", "/admin-assets/admin.css?v="
    assert_select "#sidebar", 0
    assert_select "header.topbar", 0
    assert_select "main#main form[action=?]", admin_login_path
    assert_select ".auth-brand", text: /Salary admin/
    assert_select "button[data-theme-toggle]"
  end

  private

  def delete_session_and_sign_in(admin)
    post admin_logout_url
    sign_in_as_admin(admin)
  end
end
