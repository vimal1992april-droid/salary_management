module Insights
  # Who is paid far outside what their peers earn?
  #
  # Peers are active employees with the same job title in the same country and currency, so amounts are
  # compared in local currency and exchange rates play no part. A salary is an outlier when it falls
  # outside the Tukey fences of its peer group: below Q1 - 1.5 x IQR or above Q3 + 1.5 x IQR. Groups
  # with fewer than MIN_PEERS people are not judged. The biggest outliers come first, ranked by how far
  # they are beyond the fence as a share of the peer median (a scale-free number, so INR and USD rank
  # together).
  class Outliers
    MIN_PEERS = 5
    FENCE_MULTIPLIER = 1.5
    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    SQL = <<~SQL.squish.freeze
      WITH peer_groups AS (
        SELECT job_title_id, country_id, currency_code,
               COUNT(*) AS peer_count,
               (percentile_cont(0.25) WITHIN GROUP (ORDER BY salary_amount))::numeric AS q1,
               (percentile_cont(0.5) WITHIN GROUP (ORDER BY salary_amount))::numeric AS median,
               (percentile_cont(0.75) WITHIN GROUP (ORDER BY salary_amount))::numeric AS q3
        FROM employees
        WHERE status = 'active'
        GROUP BY job_title_id, country_id, currency_code
        HAVING COUNT(*) >= :min_peers
      ),
      fenced AS (
        SELECT *, q1 - :multiplier * (q3 - q1) AS lower_fence, q3 + :multiplier * (q3 - q1) AS upper_fence
        FROM peer_groups
      )
      SELECT employees.id,
             employees.salary_amount AS salary,
             employees.currency_code,
             CASE WHEN employees.salary_amount > fenced.upper_fence THEN 'above' ELSE 'below' END AS direction,
             fenced.peer_count,
             ROUND(fenced.median, 2) AS median,
             ROUND(fenced.lower_fence, 2) AS lower_fence,
             ROUND(fenced.upper_fence, 2) AS upper_fence,
             ROUND(CASE WHEN employees.salary_amount > fenced.upper_fence
                        THEN (employees.salary_amount - fenced.upper_fence) / fenced.median
                        ELSE (fenced.lower_fence - employees.salary_amount) / fenced.median END, 2) AS deviation
      FROM employees
      JOIN fenced ON fenced.job_title_id = employees.job_title_id
                 AND fenced.country_id = employees.country_id
                 AND fenced.currency_code = employees.currency_code
      WHERE employees.status = 'active'
        AND (employees.salary_amount < fenced.lower_fence OR employees.salary_amount > fenced.upper_fence)
      ORDER BY deviation DESC, employees.id
      LIMIT :limit
    SQL

    def self.call(limit: nil)
      new(limit: limit).call
    end

    def initialize(limit:)
      @limit = Population.clamp_count(limit, default: DEFAULT_LIMIT, max: MAX_LIMIT)
    end

    def call
      rows = Employee.connection.select_all(sql).to_a
      employees = Employee.where(id: rows.map { |row| row["id"] })
                          .preload(:country, :department, :job_title, :currency).index_by(&:id)

      rows.map do |row|
        {
          employee: employees.fetch(row["id"]),
          direction: row["direction"],
          salary: row["salary"],
          currency: row["currency_code"],
          peer_count: row["peer_count"],
          peer_median: row["median"],
          fences: [ row["lower_fence"], row["upper_fence"] ],
          deviation: row["deviation"]
        }
      end
    end

    private

    def sql
      Employee.sanitize_sql_array([ SQL, { min_peers: MIN_PEERS, multiplier: FENCE_MULTIPLIER, limit: @limit } ])
    end
  end
end
