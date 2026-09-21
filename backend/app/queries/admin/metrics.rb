module Admin
  # Everything the admin dashboard shows: the counts, the pay overview and the series behind each chart. A few grouped
  # queries, a fixed number of them however many rows there are.
  #
  # A series is a list of { label:, value: } rows, ready for AdminChartHelper.
  class Metrics
    COUNTRY_LIMIT = 10
    MONTHS = 12

    Result = Data.define(:counts, :overview, :headcount_by_department, :headcount_by_country, :hires_by_year,
                         :salary_changes_by_month, :status_split, :salary_distribution)

    def self.call
      new.call
    end

    def call
      by_status = Employee.group(:status).count

      Result.new(
        counts: counts(by_status),
        overview: Insights::Overview.call,
        headcount_by_department: headcount(Department, :name),
        headcount_by_country: headcount(Country, :name, limit: COUNTRY_LIMIT),
        hires_by_year: hires_by_year,
        salary_changes_by_month: salary_changes_by_month,
        status_split: [ { label: "Active", value: by_status.fetch("active", 0) },
                        { label: "Inactive", value: by_status.fetch("inactive", 0) } ],
        salary_distribution: salary_distribution
      )
    end

    private

    def counts(by_status)
      {
        employees: by_status.values.sum,
        active_employees: by_status.fetch("active", 0),
        inactive_employees: by_status.fetch("inactive", 0),
        departments: Department.count,
        countries: Country.count,
        job_titles: JobTitle.count,
        salary_changes: SalaryChange.count,
        users: User.count,
        admins: User.admins.count,
        sessions: Session.active.count
      }
    end

    # Employees of each department (or country), biggest first, ties by name; a group with nobody in it is left out.
    def headcount(model, name_column, limit: nil)
      table = model.table_name
      rows = Employee.joins(model.model_name.singular.to_sym)
                     .group("#{table}.#{name_column}")
                     .order(Arel.sql("COUNT(*) DESC"), Arel.sql("#{table}.#{name_column}"))
      rows = rows.limit(limit) if limit
      rows.count.map { |label, value| { label: label, value: value } }
    end

    # From the first year anyone was hired to the last, with the years in between that had no hires as zero.
    def hires_by_year
      per_year = Employee.group(Arel.sql("EXTRACT(YEAR FROM employees.hire_date)::int")).count
      return [] if per_year.empty?

      (per_year.keys.min..per_year.keys.max).map { |year| { label: year.to_s, value: per_year.fetch(year, 0) } }
    end

    def salary_changes_by_month
      months = Array.new(MONTHS) { |index| Date.current.beginning_of_month << (MONTHS - 1 - index) }
      per_month = SalaryChange.where(effective_on: months.first..Date.current.end_of_month)
                              .group(Arel.sql("TO_CHAR(salary_changes.effective_on, 'YYYY-MM')")).count

      months.map { |month| { label: month.strftime("%Y-%m"), value: per_month.fetch(month.strftime("%Y-%m"), 0) } }
    end

    def salary_distribution
      Insights::Distribution.call[:buckets].map do |bucket|
        range = [ bucket[:from], bucket[:to] ].uniq.map { |amount| compact(amount) }.join("–")
        { label: range, value: bucket[:count] }
      end
    end

    def compact(amount)
      amount >= 10_000 ? "#{(amount / 1000).round}k" : amount.round.to_s
    end
  end
end
