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

    # Number of SQL statements run by the block, ignoring schema lookups and transaction control.
    # Used to prove a page of results costs a constant number of queries (no N+1).
    def count_queries(&block)
      count = 0
      counter = lambda do |*, payload|
        count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
      end
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
      count
    end
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
