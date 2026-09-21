# The API monitor's middleware. It goes just outside ActionDispatch::ShowExceptions so that it records the response the
# caller really receives. See lib/middleware/api_request_logger.rb.
require Rails.root.join("lib/middleware/api_request_logger")

Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, ApiRequestLogger
