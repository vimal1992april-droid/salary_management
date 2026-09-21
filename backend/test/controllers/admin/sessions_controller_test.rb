require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery".freeze

  setup { @admin = create(:user, :admin, email: "admin@acme.example", password: PASSWORD) }

  def sign_in_admin(email: "admin@acme.example", password: PASSWORD)
    post admin_login_url, params: { email: email, password: password }
  end

  # --- the sign-in page -----------------------------------------------------------------------------------------

  test "shows the sign-in page to anyone" do
    get admin_login_url

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "form[action=?]", admin_login_path
    assert_select "input[name=email][type=email]"
    assert_select "input[name=password][type=password]"
  end

  # --- signing in -------------------------------------------------------------------------------------------------

  test "an admin who signs in reaches the dashboard" do
    sign_in_admin

    assert_redirected_to admin_root_url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "admin@acme.example"
  end

  test "the email is matched ignoring case and surrounding spaces" do
    sign_in_admin(email: "  ADMIN@Acme.Example ")

    assert_redirected_to admin_root_url
  end

  test "a wrong password is refused with a generic message and no session" do
    sign_in_admin(password: "wrong-password")

    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid email or password"
    get admin_root_url
    assert_redirected_to admin_login_url
  end

  test "an unknown email gets exactly the same answer as a wrong password" do
    sign_in_admin(password: "wrong-password")
    wrong_password = response.body

    sign_in_admin(email: "nobody@acme.example")

    assert_response :unprocessable_entity
    assert_equal wrong_password, response.body
  end

  test "an HR manager who is not an admin cannot sign in, and is told nothing more than anyone else" do
    create(:user, email: "hr@acme.example", password: PASSWORD)

    sign_in_admin(email: "hr@acme.example")

    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid email or password"
  end

  test "repeated attempts are rate limited" do
    10.times { sign_in_admin(password: "wrong") }

    sign_in_admin

    assert_response :too_many_requests
  end

  test "the session cookie is httpOnly and SameSite=Lax" do
    sign_in_admin

    cookie = response.headers["Set-Cookie"].downcase
    assert_includes cookie, "_salary_admin"
    assert_includes cookie, "httponly"
    assert_includes cookie, "samesite=lax"
  end

  test "rejects a sign-in that lacks the forgery token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    sign_in_admin

    assert_response :unprocessable_entity
    get admin_root_url
    assert_redirected_to admin_login_url
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # --- protected pages ---------------------------------------------------------------------------------------------

  test "every admin page sends a signed-out visitor to the sign-in page" do
    get admin_root_url

    assert_redirected_to admin_login_url
  end

  test "signing in to the HR API does not open the admin panel" do
    sign_in @admin # the HR manager's API session, a different cookie

    get admin_root_url

    assert_redirected_to admin_login_url
  end

  test "signing in to the admin panel does not open the HR API" do
    sign_in_admin

    get api_employees_url

    assert_response :unauthorized
  end

  test "an admin who loses the role loses access at once" do
    sign_in_admin
    @admin.update!(admin: false)

    get admin_root_url

    assert_redirected_to admin_login_url
  end

  test "the session expires after 8 hours" do
    sign_in_admin

    travel 9.hours do
      get admin_root_url

      assert_redirected_to admin_login_url
    end
  end

  # --- signing out ---------------------------------------------------------------------------------------------------

  test "signing out ends the session" do
    sign_in_admin

    post admin_logout_url

    assert_redirected_to admin_login_url
    get admin_root_url
    assert_redirected_to admin_login_url
  end

  test "the sign-out button is a plain form post, which is all a browser can send without a script" do
    sign_in_admin

    get admin_root_url

    # A form can only GET or POST. Rails fakes DELETE with a hidden _method field that Rack::MethodOverride reads,
    # and an API-only app does not have that middleware, so a "delete" button would go nowhere.
    assert_select "form[action=?][method=post]", admin_logout_path do
      assert_select "input[name=_method]", 0
      assert_select "button, input[type=submit]", text: /Sign out/
    end
  end

  test "a signed-in admin who opens the sign-in page goes straight to the dashboard" do
    sign_in_admin

    get admin_login_url

    assert_redirected_to admin_root_url
  end

  # --- what /admin must not swallow ---------------------------------------------------------------------------------

  test "an unknown admin path is a plain 404, not the React app" do
    sign_in_admin

    get "/admin/nope"

    assert_response :not_found
    assert_not_includes response.body, %(<div id="root"></div>)
  end
end
