require "test_helper"

# In production Rails serves the built React app, so the whole product is one origin and one deploy.
# Pages are client-side routes: any browser URL must return the app shell, and the app takes it from there.
class FrontendControllerTest < ActionDispatch::IntegrationTest
  APP_SHELL = %(<div id="root"></div>).freeze

  [ "/", "/login", "/employees", "/employees/new", "/employees/7", "/employees/7/edit", "/insights" ].each do |path|
    test "serves the app shell at #{path}, without needing a session" do
      get path

      assert_response :success
      assert_equal "text/html", response.media_type
      assert_includes response.body, APP_SHELL
    end
  end

  test "serves the app shell to a client that accepts anything, such as curl or a health check" do
    # Browsers send a long Accept list; plain clients send just */*. Both must get the pages.
    get "/employees", headers: { "Accept" => "*/*" }

    assert_response :success
    assert_includes response.body, APP_SHELL
  end

  test "tells the browser to check for a new shell each time, so a new deploy is picked up at once" do
    [ "/", "/employees" ].each do |path|
      get path

      assert_includes response.headers["Cache-Control"], "no-cache", "#{path} must not be cached"
    end
  end

  test "never lets the static file server hand out the shell for /, where it would be cached for a year" do
    # public/index.html would otherwise be served for "/" by the static middleware, bypassing the no-cache above,
    # and a browser would keep an old shell that names assets a later deploy has removed.
    assert_not_equal "index", Rails.configuration.public_file_server.index_name
  end

  test "does not answer for unknown API paths with the app shell" do
    get "/api/nope"

    assert_response :not_found
    assert_not_includes response.body, APP_SHELL
  end

  test "does not answer for a missing file with the app shell, so a stale asset is a clear 404" do
    get "/assets/index-abc123.js"

    assert_response :not_found
    assert_not_includes response.body, APP_SHELL
  end

  test "only answers GET requests for pages" do
    post "/employees"

    assert_response :not_found
  end

  test "leaves the health checks and the API alone" do
    get "/up"
    assert_response :success

    get api_health_url
    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
  end

  test "explains itself when the frontend has not been built" do
    original = Rails.configuration.x.frontend_index
    Rails.configuration.x.frontend_index = Rails.root.join("tmp/does-not-exist.html")

    get "/employees"

    assert_response :not_found
    assert_includes response.body, "The frontend has not been built"
    # In development the app is served by Vite, not by Rails, and opening the API's port is an easy mistake.
    assert_includes response.body, "http://localhost:5173"
  ensure
    Rails.configuration.x.frontend_index = original
  end
end
