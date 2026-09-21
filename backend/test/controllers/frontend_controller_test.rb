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

  test "tells the browser to check for a new shell each time, so a new deploy is picked up at once" do
    get "/employees"

    assert_includes response.headers["Cache-Control"], "no-cache"
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
  ensure
    Rails.configuration.x.frontend_index = original
  end
end
