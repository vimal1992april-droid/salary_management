require "test_helper"

class Api::HealthControllerTest < ActionDispatch::IntegrationTest
  test "reports the API and database as up" do
    get api_health_url

    assert_response :success
    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal true, body["database"]
  end

  test "reports the database as down without failing the request, if it cannot be reached" do
    replace_method(ActiveRecord::Base.connection, :select_value, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
      get api_health_url
    end

    assert_response :success
    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal false, body["database"]
  end
end
