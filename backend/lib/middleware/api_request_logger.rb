# Records each call to the JSON API for the admin's API monitor.
#
# It sits outside ActionDispatch::ShowExceptions, so it sees the response a caller actually gets, including the
# error pages, and it sees a failure that escapes the app, which it records as a 500 and then lets carry on. It has
# to stay out of the way: whatever goes wrong while recording is logged and never reaches the caller.
#
# Loaded explicitly by config/initializers/api_monitor.rb (this directory is not autoloaded, since a middleware has
# to exist while the app boots); everything it calls lives in app/services/api_monitor and is autoloaded as usual.
class ApiRequestLogger
  API_PATH = %r{\A/api(/|\z)}

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless monitored?(env)

    started = clock
    request_body = read_request_body(env)

    begin
      status, headers, body = @app.call(env)
    rescue Exception # rubocop:disable Lint/RescueException -- recorded, then raised again untouched
      record(env, started, request_body, status: 500)
      raise
    end

    body = buffered(body)
    record(env, started, request_body, status: status, headers: headers, body: body)
    [ status, headers, body ]
  end

  private

  def monitored?(env)
    ApiMonitor.enabled? && env["PATH_INFO"].to_s.match?(API_PATH)
  end

  def clock
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Reads the body ahead of the app and puts it back. A body without a known, reasonable size is left unread.
  def read_request_body(env)
    input = env["rack.input"]
    length = env["CONTENT_LENGTH"].to_i
    return unless input.respond_to?(:rewind) && length.positive? && length <= ApiMonitor::Redactor::MAX_PARSE_BYTES

    input.read(length).tap { input.rewind }
  rescue StandardError
    nil
  end

  # The response body is an enumerable that can be read once, so it is read into an array, which is a body too. A
  # file (which answers to_path) is left alone: it is neither read nor recorded.
  def buffered(body)
    return body if body.respond_to?(:to_path)

    chunks = []
    body.each { |chunk| chunks << chunk }
    body.close if body.respond_to?(:close)
    chunks
  end

  def record(env, started, request_body, status:, headers: {}, body: [])
    ApiMonitor::Recorder.call(
      http_method: env["REQUEST_METHOD"], path: env["PATH_INFO"], query_string: env["QUERY_STRING"],
      route: matched_route(env), status: status,
      duration_ms: (clock - started) * 1000, user_id: env[ApiMonitor::USER_ENV_KEY],
      ip_address: (env["action_dispatch.remote_ip"] || env["REMOTE_ADDR"]).to_s.presence,
      request_body: request_body, request_content_type: env["CONTENT_TYPE"],
      response_body: response_text(body), response_content_type: headers["content-type"] || headers["Content-Type"]
    )
  rescue StandardError => error
    Rails.logger.error("ApiMonitor: could not record #{env['REQUEST_METHOD']} #{env['PATH_INFO']}: #{error.class}: #{error.message}")
  end

  # The router records a route before it knows the route will take the request, so a call that no API route wants is
  # left holding the React catch-all ("/*path"). Only a route under /api counts as a match.
  def matched_route(env)
    pattern = ActionDispatch::Request.new(env).route_uri_pattern
    pattern if pattern&.start_with?("/api")
  end

  def response_text(body)
    return if body.respond_to?(:to_path)

    body.join.dup.force_encoding(Encoding::UTF_8).scrub
  end
end
