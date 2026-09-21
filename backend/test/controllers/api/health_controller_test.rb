require "test_helper"

class Api::HealthControllerTest < ActionDispatch::IntegrationTest
  test "reports the API and database as up" do
    get api_health_url

    assert_response :success
    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal true, body["database"]
  end
end
