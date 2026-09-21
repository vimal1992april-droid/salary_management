module ApiMonitor
  # What the recorded calls of the last 24 hours say about the API, in a fixed number of queries.
  #
  #   stats = ApiMonitor::Stats.call
  #   stats.summary     # totals, failures, timings
  #   stats.endpoints   # one row for every endpoint the API offers, called or not, with a state
  #   stats.unmatched   # calls that matched no endpoint (mostly 404s)
  #   stats.hourly      # calls in each of the last 24 hours, the current hour last
  #
  # An endpoint's state: idle (nothing recorded), healthy (calls and no server error; a caller's mistakes do not
  # count), degraded (it failed on the server earlier but its latest call was fine) or failing (its latest call failed
  # on the server).
  class Stats
    HOURS = 24
    CLASSES = %w[2xx 3xx 4xx 5xx].freeze

    Summary = Data.define(:total, :by_class, :client_errors, :server_errors, :average_ms, :p95_ms) do
      def server_error_percent
        total.zero? ? 0 : server_errors * 100.0 / total
      end
    end
    EndpointRow = Data.define(:endpoint, :calls, :client_errors, :server_errors, :average_ms, :last_called_at,
                              :last_status, :state)
    Result = Data.define(:summary, :endpoints, :unmatched, :hourly)

    CLIENT_ERRORS = "COUNT(*) FILTER (WHERE status BETWEEN 400 AND 499)".freeze
    SERVER_ERRORS = "COUNT(*) FILTER (WHERE status >= 500)".freeze

    def self.call
      new.call
    end

    def call
      @since = Time.current.beginning_of_hour - (HOURS - 1).hours
      @scope = ApiRequest.where(created_at: @since..)

      Result.new(summary: summary, endpoints: endpoints, unmatched: @scope.where(route: nil).count, hourly: hourly)
    end

    private

    def summary
      total, client_errors, server_errors, average, p95 = @scope.pick(
        Arel.sql("COUNT(*)"), Arel.sql(CLIENT_ERRORS), Arel.sql(SERVER_ERRORS),
        Arel.sql("AVG(duration_ms)"), Arel.sql("percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms)")
      )
      per_class = @scope.group(Arel.sql("status / 100")).count

      Summary.new(total: total, by_class: CLASSES.index_with { |name| per_class.fetch(name.to_i, 0) },
                  client_errors: client_errors, server_errors: server_errors, average_ms: average&.to_f, p95_ms: p95&.to_f)
    end

    def endpoints
      matched = @scope.where.not(route: nil)
      totals = matched.group(:http_method, :route).pluck(
        :http_method, :route, Arel.sql("COUNT(*)"), Arel.sql(CLIENT_ERRORS), Arel.sql(SERVER_ERRORS),
        Arel.sql("AVG(duration_ms)"), Arel.sql("MAX(created_at)")
      ).index_by { |method, route, *| [ method, route ] }
      last_status = matched.select(Arel.sql("DISTINCT ON (http_method, route) http_method, route, status"))
                           .order(:http_method, :route, created_at: :desc, id: :desc)
                           .to_h { |call| [ [ call.http_method, call.route ], call.status ] }

      Endpoints.all.map do |endpoint|
        key = [ endpoint.http_method, endpoint.path ]
        _, _, calls, client_errors, server_errors, average, last_called_at = totals[key]
        row(endpoint, calls.to_i, client_errors.to_i, server_errors.to_i, average, last_called_at, last_status[key])
      end
    end

    def row(endpoint, calls, client_errors, server_errors, average, last_called_at, last_status)
      EndpointRow.new(endpoint: endpoint, calls: calls, client_errors: client_errors, server_errors: server_errors,
                      average_ms: average&.to_f, last_called_at: last_called_at, last_status: last_status,
                      state: state(calls, server_errors, last_status))
    end

    def state(calls, server_errors, last_status)
      return :idle if calls.zero?
      return :failing if last_status >= 500

      server_errors.positive? ? :degraded : :healthy
    end

    def hourly
      per_hour = @scope.group(Arel.sql("date_trunc('hour', created_at)")).count.transform_keys(&:to_i)

      Array.new(HOURS) do |index|
        hour = @since + index.hours
        { label: hour.strftime("%H:00"), value: per_hour.fetch(hour.to_i, 0) }
      end
    end
  end
end
