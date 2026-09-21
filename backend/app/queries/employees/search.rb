module Employees
  # The employee directory query: filters, text search, sorting and pagination as one testable object.
  #
  #   result = Employees::Search.call(q: "asha", country_id: 3, sort: "salary", direction: "desc", page: 2)
  #   result.records      # the page, with everything the serializer needs preloaded
  #   result.total        # matches across all pages
  #
  # Pass `paginate: false` to get every match at once (used by the CSV export).
  class Search
    # Raised for parameters that name something that does not exist (a sort column, a status).
    InvalidParameter = Class.new(ArgumentError)

    DEFAULT_SORT = "name".freeze
    DEFAULT_DIRECTION = "asc".freeze
    DIRECTIONS = %w[asc desc].freeze
    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100

    # One SQL condition per searchable column; each search word must match at least one of them.
    TEXT_MATCH = %w[first_name last_name email employee_number]
                   .map { |column| "employees.#{column} ILIKE :pattern" }.join(" OR ").freeze

    # Salary sorts by its USD value so amounts in different currencies compare fairly.
    SORTS = {
      "name" => ->(scope, dir) { scope.order(last_name: dir, first_name: dir) },
      "employee_number" => ->(scope, dir) { scope.order(employee_number: dir) },
      "hire_date" => ->(scope, dir) { scope.order(hire_date: dir) },
      "salary" => lambda { |scope, dir|
        usd = Employee.arel_table[:salary_amount] * Currency.arel_table[:rate_to_usd]
        scope.joins(:currency).order(usd.public_send(dir))
      },
      "country" => ->(scope, dir) { scope.joins(:country).order(Country.arel_table[:name].public_send(dir)) },
      "department" => ->(scope, dir) { scope.joins(:department).order(Department.arel_table[:name].public_send(dir)) },
      "job_title" => ->(scope, dir) { scope.joins(:job_title).order(JobTitle.arel_table[:name].public_send(dir)) }
    }.freeze

    Result = Struct.new(:records, :page, :per_page, :total) do
      def total_pages
        (total.to_f / per_page).ceil
      end
    end

    def self.call(**options)
      new(**options).call
    end

    def initialize(q: nil, country_id: nil, department_id: nil, job_title_id: nil, status: nil,
                   sort: nil, direction: nil, page: nil, per_page: nil, paginate: true)
      @q = q
      @paginate = paginate
      @filters = { country_id:, department_id:, job_title_id:, status: }.compact_blank
      @sort = validated(sort.presence || DEFAULT_SORT, SORTS.keys, "sort")
      @direction = validated(direction.presence || DEFAULT_DIRECTION, DIRECTIONS, "direction")
      @page = [ Integer(page, exception: false) || 1, 1 ].max
      @per_page = (Integer(per_page, exception: false) || DEFAULT_PER_PAGE).clamp(1, MAX_PER_PAGE)
      validate_status!
    end

    def call
      matches = matching(Employee.where(@filters))
      total = matches.count
      records = sorted(matches).preload(:country, :department, :job_title, :currency)
      return Result.new(records, 1, [ total, 1 ].max, total) unless @paginate

      Result.new(records.limit(@per_page).offset((@page - 1) * @per_page), @page, @per_page, total)
    end

    private

    def matching(scope)
      @q.to_s.split.reduce(scope) do |memo, word|
        memo.where(TEXT_MATCH, pattern: "%#{Employee.sanitize_sql_like(word)}%")
      end
    end

    # `id` is the final tie-breaker, so equal values still have one stable order and pages never overlap.
    def sorted(scope)
      SORTS.fetch(@sort).call(scope, @direction).order(:id)
    end

    def validated(value, allowed, name)
      return value if allowed.include?(value)

      raise InvalidParameter, "Unknown #{name} '#{value}'. Use one of: #{allowed.join(', ')}"
    end

    def validate_status!
      status = @filters[:status]
      return if status.nil? || Employee.statuses.key?(status.to_s)

      raise InvalidParameter, "Unknown status '#{status}'. Use one of: #{Employee.statuses.keys.join(', ')}"
    end
  end
end
