module ApiMonitor
  # The recorded calls as a list: newest first, paged, and filtered by whatever the administrator chose. A filter that
  # makes no sense is ignored rather than failing, so a hand-edited address still shows a page.
  #
  #   result = ApiMonitor::Log.page(http_method: "POST", status: "5xx", q: "employees", page: 2)
  #
  # The list leaves out the payloads, which can be large; ApiMonitor::Log.find returns one call with everything.
  class Log
    # Stands for "the calls that matched no endpoint" in the route filter.
    UNMATCHED = "(no route)".freeze
    METHODS = %w[GET POST PATCH PUT DELETE HEAD OPTIONS].freeze
    PAYLOAD_COLUMNS = %w[request_body response_body].freeze
    MAX_ID_DIGITS = 18

    def self.page(**options)
      new(**options).page
    end

    def self.find(id)
      ApiRequest.find(id)
    end

    def initialize(http_method: nil, status: nil, route: nil, q: nil, user_id: nil, min_duration: nil, page: nil,
                   per_page: nil)
      @filters = { http_method: http_method, status: status, route: route, q: q, user_id: user_id,
                   min_duration: min_duration }
      @page = page
      @per_page = per_page
    end

    def page
      scope = filtered
      total = scope.count
      per_page = Admin::Pagination.per_page(@per_page)
      page = Admin::Pagination.page(@page, total, per_page)

      records = scope.select(*(ApiRequest.column_names - PAYLOAD_COLUMNS)).order(created_at: :desc, id: :desc)
                     .limit(per_page).offset((page - 1) * per_page).to_a
      Admin::Pagination::Result.new(records, page, per_page, total)
    end

    private

    def filtered
      scope = ApiRequest.all
      scope = by_method(scope)
      scope = by_status(scope)
      scope = by_route(scope)
      scope = by_search(scope)
      scope = by_user(scope)
      by_duration(scope)
    end

    def by_method(scope)
      method = @filters[:http_method].to_s.upcase
      METHODS.include?(method) ? scope.where(http_method: method) : scope
    end

    # "404" is one status, "4xx" is every 4xx.
    def by_status(scope)
      status = @filters[:status].to_s.strip.downcase
      if status.match?(/\A[1-5]\d\d\z/)
        scope.where(status: status.to_i)
      elsif status.match?(/\A[1-5]xx\z/)
        scope.where(status: (status.to_i * 100)..((status.to_i * 100) + 99))
      else
        scope
      end
    end

    def by_route(scope)
      route = @filters[:route].to_s
      return scope if route.blank?

      route == UNMATCHED ? scope.where(route: nil) : scope.where(route: route)
    end

    def by_search(scope)
      text = @filters[:q].to_s.strip
      return scope if text.empty?

      pattern = "%#{ApiRequest.sanitize_sql_like(text)}%"
      table = ApiRequest.arel_table
      scope.where(table[:path].matches(pattern, nil, false).or(table[:query_string].matches(pattern, nil, false)))
    end

    def by_user(scope)
      user_id = @filters[:user_id].to_s
      user_id.match?(/\A\d{1,#{MAX_ID_DIGITS}}\z/) ? scope.where(user_id: user_id.to_i) : scope
    end

    def by_duration(scope)
      minimum = Float(@filters[:min_duration].to_s, exception: false)
      minimum&.positive? ? scope.where(ApiRequest.arel_table[:duration_ms].gteq(minimum)) : scope
    end
  end
end
