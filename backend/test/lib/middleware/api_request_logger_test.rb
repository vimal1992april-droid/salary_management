require "test_helper"

# The rest of the middleware is exercised through the whole stack in test/integration/api_monitor_test.rb; this one
# case (a request body that cannot be read) needs to reach into the Rack env directly to force it.
class ApiRequestLoggerTest < ActiveSupport::TestCase
  test "still records the call, without a request body, if the request body cannot be read" do
    input = Object.new
    def input.rewind; end
    def input.read(*) = raise(IOError, "broken pipe")

    env = Rack::MockRequest.env_for("/api/employees", method: "POST")
    env["CONTENT_LENGTH"] = "9"
    env["CONTENT_TYPE"] = "application/json"
    env["rack.input"] = input
    app = ->(_env) { [ 200, { "content-type" => "application/json" }, [ "{}" ] ] }

    with_monitor_settings do
      status, = ApiRequestLogger.new(app).call(env)

      assert_equal 200, status
    end

    assert_nil ApiRequest.order(:id).last.request_body
  end
end
