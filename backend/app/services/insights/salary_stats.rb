module Insights
  # How pay is spread within each country, department or job title: headcount, min, quartiles, median,
  # max and mean, all in USD. Percentiles are linearly interpolated (PostgreSQL percentile_cont), so the
  # median of 10k, 20k, 30k and 100k is 25k.
  class SalaryStats
    GROUPS = {
      "country" => { association: :country, model: Country },
      "department" => { association: :department, model: Department },
      "job_title" => { association: :job_title, model: JobTitle }
    }.freeze

    # Filters narrow the population, e.g. job titles within a single country.
    def self.call(group_by:, **filters)
      new(group_by: group_by, filters: filters).call
    end

    def initialize(group_by:, filters:)
      @group = GROUPS.fetch(group_by.to_s) do
        raise InvalidParameter, "Unknown group_by '#{group_by}'. Use one of: #{GROUPS.keys.join(', ')}"
      end
      @filters = filters
    end

    def call
      id = @group[:model].arel_table[:id]
      name = @group[:model].arel_table[:name]
      usd = Population::USD_SALARY

      rows = Population.scope(@filters)
                       .joins(@group[:association])
                       .group(id, name)
                       .order(name)
                       .pluck(
                         id, name, Arel.sql("COUNT(*)"),
                         Arel.sql("ROUND(MIN(#{usd}), 2)"), Arel.sql(Population.percentile(0.25)),
                         Arel.sql(Population.percentile(0.5)), Arel.sql(Population.percentile(0.75)),
                         Arel.sql("ROUND(MAX(#{usd}), 2)"), Arel.sql("ROUND(AVG(#{usd}), 2)")
                       )

      rows.map do |group_id, group_name, headcount, min, p25, median, p75, max, mean|
        { group: { id: group_id, name: group_name }, headcount: headcount,
          min: min, p25: p25, median: median, p75: p75, max: max, mean: mean }
      end
    end
  end
end
