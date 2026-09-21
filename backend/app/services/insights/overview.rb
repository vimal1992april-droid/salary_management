module Insights
  # The headline numbers for the whole organisation.
  class Overview
    def self.call
      new.call
    end

    def call
      headcount, countries, departments, payroll, average, median = Population.scope.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(DISTINCT employees.country_id)"),
        Arel.sql("COUNT(DISTINCT employees.department_id)"),
        Arel.sql("COALESCE(ROUND(SUM(#{Population::USD_SALARY}), 2), 0)"),
        Arel.sql("ROUND(AVG(#{Population::USD_SALARY}), 2)"),
        Arel.sql(Population.percentile(0.5))
      )

      {
        headcount: headcount,
        countries: countries,
        departments: departments,
        payroll_usd: payroll,
        average_salary_usd: average,
        median_salary_usd: median,
        rates_as_of: oldest_rate_date
      }
    end

    private

    # The USD figures are only as fresh as the oldest rate behind them.
    def oldest_rate_date
      Currency.where(code: Employee.active.select(:currency_code)).minimum(:rate_as_of)
    end
  end
end
