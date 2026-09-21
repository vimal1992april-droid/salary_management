ENV["RAILS_ENV"] ||= "test"

require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Merge coverage from the forked workers
    parallelize_setup { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
    parallelize_teardown { |_worker| SimpleCov.result }

    include FactoryBot::Syntax::Methods
  end
end

module ActionDispatch
  class IntegrationTest
    # Login attempts are rate limited through Rails.cache, so start every test with a clean slate.
    setup { Rails.cache.clear }

    # Signs in through the real login endpoint, so the session cookie is set exactly as in production.
    def sign_in(user = create(:user), password: "correct-horse-battery")
      post api_session_url, params: { email: user.email, password: password }, as: :json
      assert_response :created
      user
    end
  end
end
