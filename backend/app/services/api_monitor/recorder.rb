module ApiMonitor
  # Writes one call to the API into the log, using the Redactor's rules for both payloads, and now and then trims the
  # log to its size limit.
  module Recorder
    PATH_LIMIT = 2_000
    FORMAT_SUFFIX = "(.:format)".freeze

    module_function

    def call(http_method:, path:, status:, duration_ms:, route: nil, query_string: nil, user_id: nil, ip_address: nil,
             request_body: nil, request_content_type: nil, response_body: nil, response_content_type: nil)
      request = Redactor.call(request_body, content_type: request_content_type)
      response = Redactor.call(response_body, content_type: response_content_type)

      ApiRequest.create!(
        http_method: http_method, path: path.to_s.first(PATH_LIMIT), route: route&.delete_suffix(FORMAT_SUFFIX).presence,
        query_string: Redactor.query_string(query_string), status: status, duration_ms: duration_ms.to_f.round(2),
        user_id: user_id, ip_address: ip_address,
        request_content_type: request_content_type, request_body: request.text, request_truncated: request.truncated,
        response_content_type: response_content_type, response_body: response.text, response_truncated: response.truncated
      ).tap { |recorded| prune_if_due(recorded) }
    end

    # Deciding by the row's id needs no counter, so it works across server processes: every Nth row does the trimming.
    def prune_if_due(recorded)
      settings = ApiMonitor.settings
      ApiRequest.prune!(keep: settings.max_rows) if (recorded.id % settings.prune_every).zero?
    end
    private_class_method :prune_if_due
  end
end
