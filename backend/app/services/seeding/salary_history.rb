module Seeding
  # Gives seeded employees a believable salary history: one to three past raises, worked out backwards
  # from today's salary so every history ends exactly where the employee is now.
  #
  # Each employee gets their own random generator derived from the seed and their employee number, so
  # the result depends on nothing but (seed, employee): it is deterministic and a re-run is idempotent
  # (employees who already have history are skipped, and the ones with none simply get none again).
  class SalaryHistory
    BATCH_SIZE = 1_000
    MAX_CHANGES = 3
    COUNT_ODDS = [ 0.30, 0.35, 0.25, 0.10 ].freeze # chance of 0, 1, 2 or 3 past raises
    REASONS = { "Annual review" => 55, "Market adjustment" => 20, "Promotion" => 15, "Role change" => 10 }.freeze
    RAISES = { "Promotion" => 0.10..0.18, "Role change" => 0.08..0.14 }.freeze
    DEFAULT_RAISE = 0.03..0.09
    ROUNDING = 100 # round amounts to the nearest 100 units of local currency

    def initialize(seed: Runner::DEFAULT_SEED)
      @seed = seed
    end

    # Returns the number of salary changes created.
    def load!
      created = 0
      Employee.where.missing(:salary_changes).find_in_batches(batch_size: BATCH_SIZE) do |employees|
        rows = employees.flat_map { |employee| rows_for(employee) }
        SalaryChange.insert_all(rows, returning: false) if rows.any?
        created += rows.size
      end
      created
    end

    private

    def rows_for(employee)
      random = Random.new((@seed * 1_000_003) + employee.employee_number.delete("^0-9").to_i)
      tenure_days = (Catalog::REFERENCE_DATE - employee.hire_date).to_i
      count = [ change_count(random), tenure_days / 365, MAX_CHANGES ].min
      return [] if count.zero?

      dates = effective_dates(employee.hire_date, tenure_days, count, random)
      amount = employee.salary_amount

      # Work backwards from the current salary, so the newest change ends at exactly that amount.
      dates.each_index.reverse_each.map do |index|
        reason = weighted_reason(random)
        previous = round(amount.to_f / (1 + random.rand(RAISES.fetch(reason, DEFAULT_RAISE))))
        row = row(employee, dates[index], reason, previous, amount)
        amount = previous
        row
      end.reverse
    end

    def change_count(random)
      roll = random.rand
      cumulative = 0.0
      COUNT_ODDS.each_with_index do |odds, count|
        cumulative += odds
        return count if roll < cumulative
      end
      MAX_CHANGES
    end

    # Evenly spread through the employee's time with the company, with a little jitter that is always
    # smaller than the gap between changes, so the dates stay in order.
    def effective_dates(hire_date, tenure_days, count, random)
      step = tenure_days / (count + 1)
      (1..count).map { |index| hire_date + (step * index) + random.rand(0..[ step / 6, 30 ].min) }
    end

    def weighted_reason(random)
      roll = random.rand * REASONS.values.sum
      REASONS.each do |reason, weight|
        roll -= weight
        return reason if roll.negative?
      end
      REASONS.keys.last
    end

    def round(value)
      (value / ROUNDING).round * ROUNDING
    end

    def row(employee, date, reason, previous, new_amount)
      recorded_at = Time.utc(date.year, date.month, date.day, 9)
      {
        employee_id: employee.id,
        previous_amount: previous,
        previous_currency_code: employee.currency_code,
        new_amount: new_amount,
        new_currency_code: employee.currency_code,
        effective_on: date,
        reason: reason,
        changed_by_id: nil,
        created_at: recorded_at,
        updated_at: recorded_at
      }
    end
  end
end
