module Insights
  # The highest (or lowest) paid active employees, ranked by USD value so currencies compare fairly.
  class TopEarners
    DIRECTIONS = %w[asc desc].freeze
    DEFAULT_LIMIT = 10
    MAX_LIMIT = 50

    def self.call(direction: nil, limit: nil)
      new(direction: direction, limit: limit).call
    end

    def initialize(direction:, limit:)
      @direction = direction.presence || "desc"
      unless DIRECTIONS.include?(@direction)
        raise InvalidParameter, "Unknown direction '#{@direction}'. Use one of: #{DIRECTIONS.join(', ')}"
      end

      @limit = Population.clamp_count(limit, default: DEFAULT_LIMIT, max: MAX_LIMIT)
    end

    def call
      usd = Employee.arel_table[:salary_amount] * Currency.arel_table[:rate_to_usd]

      Population.scope
                .order(usd.public_send(@direction), :id)
                .limit(@limit)
                .preload(:country, :department, :job_title, :currency)
    end
  end
end
