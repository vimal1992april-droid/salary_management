module Insights
  # A histogram of USD salaries: the range from lowest to highest is cut into equal-width buckets. Empty
  # buckets are kept so a chart has no gaps, and the highest salary belongs to the last bucket.
  class Distribution
    DEFAULT_BUCKETS = 10
    MAX_BUCKETS = 50

    def self.call(bucket_count: nil, **filters)
      new(bucket_count: bucket_count, filters: filters).call
    end

    def initialize(bucket_count:, filters:)
      @bucket_count = Population.clamp_count(bucket_count, default: DEFAULT_BUCKETS, max: MAX_BUCKETS)
      @scope = Population.scope(filters)
    end

    def call
      min, max = @scope.pick(Arel.sql("MIN(#{Population::USD_SALARY})"), Arel.sql("MAX(#{Population::USD_SALARY})"))
      return { min: nil, max: nil, buckets: [] } if min.nil?
      return { min: min.round(2), max: max.round(2), buckets: [ single_bucket(min) ] } if min == max

      width = (max - min) / @bucket_count
      counts = @scope.group(Arel.sql(bucket_index_sql(min, width))).count

      {
        min: min.round(2),
        max: max.round(2),
        buckets: Array.new(@bucket_count) do |index|
          upper = index == @bucket_count - 1 ? max : min + (width * (index + 1))
          { from: (min + (width * index)).round(2), to: upper.round(2), count: counts.fetch(index, 0) }
        end
      }
    end

    private

    def single_bucket(value)
      { from: value.round(2), to: value.round(2), count: @scope.count }
    end

    # LEAST folds the top salary, which falls exactly on the upper edge, into the last bucket.
    def bucket_index_sql(min, width)
      Employee.sanitize_sql_array(
        [ "LEAST(FLOOR((#{Population::USD_SALARY} - ?) / ?)::int, ?)", min, width, @bucket_count - 1 ]
      )
    end
  end
end
