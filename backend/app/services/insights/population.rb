module Insights
  # The people every insight is computed over: active employees, with each salary convertible to USD
  # through the currency's static rate. Keeping this in one place is what makes the numbers agree.
  module Population
    USD_SALARY = "employees.salary_amount * currencies.rate_to_usd".freeze
    FILTERS = %i[country_id department_id job_title_id].freeze

    module_function

    def scope(filters = {})
      Employee.active.joins(:currency).where(filters.to_h.symbolize_keys.slice(*FILTERS).compact_blank)
    end

    # Rounded to cents, and NULL for an empty set.
    def percentile(fraction)
      "ROUND(percentile_cont(#{fraction}) WITHIN GROUP (ORDER BY #{USD_SALARY})::numeric, 2)"
    end

    def clamp_count(value, default:, max:)
      (Integer(value, exception: false) || default).clamp(1, max)
    end
  end
end
