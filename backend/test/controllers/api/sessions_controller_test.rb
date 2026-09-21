require "test_helper"

class Api::SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "correct-horse-battery".freeze

  setup { @user = create(:user, email: "hr@acme.example", password: PASSWORD) }

  # --- POST /api/session (log in) -------------------------------------------

  test "logging in with valid credentials returns the user and starts a session" do
    assert_difference -> { @user.sessions.count }, 1 do
      post api_session_url, params: { email: "hr@acme.example", password: PASSWORD }, as: :json
    end

    assert_response :created
    assert_equal({ "id" => @user.id, "email" => "hr@acme.example" }, response.parsed_body["user"])
  end

  test "the email is matched ignoring case and surrounding spaces" do
    post api_session_url, params: { email: " HR@Acme.Example ", password: PASSWORD }, as: :json

    assert_response :created
  end

  test "the session cookie is httpOnly and SameSite=Lax" do
    post api_session_url, params: { email: "hr@acme.example", password: PASSWORD }, as: :json

    cookie = response.headers["Set-Cookie"].downcase
    assert_includes cookie, "session_id="
    assert_includes cookie, "httponly"
    assert_includes cookie, "samesite=lax"
  end

  test "the session records the client's IP address and user agent" do
    post api_session_url, params: { email: "hr@acme.example", password: PASSWORD }, as: :json,
                          headers: { "User-Agent" => "Mozilla/5.0 (test)" }

    session = @user.sessions.last
    assert_equal "Mozilla/5.0 (test)", session.user_agent
    assert_predicate session.ip_address, :present?
  end

  test "a wrong password is rejected with a generic message" do
    assert_no_difference -> { Session.count } do
      post api_session_url, params: { email: "hr@acme.example", password: "wrong-password" }, as: :json
    end

    assert_response :unauthorized
    assert_equal "invalid_credentials", response.parsed_body.dig("error", "code")
    assert_equal "Invalid email or password", response.parsed_body.dig("error", "message")
  end

  test "an unknown email gets exactly the same response as a wrong password" do
    post api_session_url, params: { email: "hr@acme.example", password: "wrong-password" }, as: :json
    wrong_password = response.parsed_body

    post api_session_url, params: { email: "nobody@acme.example", password: PASSWORD }, as: :json

    assert_response :unauthorized
    assert_equal wrong_password, response.parsed_body
  end

  test "missing credentials are rejected like any other bad login" do
    post api_session_url, params: {}, as: :json

    assert_response :unauthorized
    assert_equal "invalid_credentials", response.parsed_body.dig("error", "code")
  end

  test "repeated login attempts are rate limited" do
    10.times { post api_session_url, params: { email: "hr@acme.example", password: "wrong" }, as: :json }

    post api_session_url, params: { email: "hr@acme.example", password: PASSWORD }, as: :json

    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body.dig("error", "code")
  end

  # --- GET /api/session (who am I) ------------------------------------------

  test "the current user is returned while signed in" do
    sign_in @user

    get api_session_url

    assert_response :success
    assert_equal "hr@acme.example", response.parsed_body.dig("user", "email")
  end

  test "asking who I am without a session is unauthorized" do
    get api_session_url

    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  test "a tampered session cookie is rejected" do
    sign_in @user

    cookies[:session_id] = "tampered"
    get api_session_url

    assert_response :unauthorized
  end

  test "a session older than 14 days is rejected" do
    sign_in @user

    travel 15.days do
      get api_session_url

      assert_response :unauthorized
    end
  end

  # --- DELETE /api/session (log out) ----------------------------------------

  test "logging out ends the session" do
    sign_in @user

    assert_difference -> { Session.count }, -1 do
      delete api_session_url
    end
    assert_response :no_content

    get api_session_url
    assert_response :unauthorized
  end

  test "a copied cookie stops working once the session is ended on the server" do
    sign_in @user
    copied_cookie = cookies[:session_id]

    delete api_session_url
    cookies[:session_id] = copied_cookie
    get api_session_url

    assert_response :unauthorized
  end

  test "logging out without a session is unauthorized" do
    delete api_session_url

    assert_response :unauthorized
  end

  # --- what stays open ------------------------------------------------------

  test "the health check does not require a session" do
    get api_health_url

    assert_response :success
  end
end
