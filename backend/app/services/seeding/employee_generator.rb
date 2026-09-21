module Seeding
  # Produces employee rows (hashes ready for `insert_all`) from a seeded random generator.
  #
  # Every random draw happens in a fixed order per employee, so the output depends only on
  # `count`, `seed` and the reference ids, never on batching, the clock or the database.
  class EmployeeGenerator
    INACTIVE_SHARE = 0.05
    MAX_TENURE_DAYS = 12 * 365
    TENURE_RAISE_PER_YEAR = 0.012
    MAX_TENURE_YEARS_COUNTED = 10
    # Every 500th employee is a deliberate pay outlier, so outlier detection has something to find.
    OUTLIER_EVERY = 500
    OUTLIER_MULTIPLIER = 2.3
    SALARY_ROUNDING = 100 # round to the nearest 100 units of local currency

    RATES_TO_USD = Catalog::CURRENCIES.to_h { |currency| [ currency[:code], Float(currency[:rate_to_usd]) ] }.freeze

    # ids: { countries: { "IN" => 1 }, departments: { "Sales" => 2 }, job_titles: { "Staff Engineer" => 3 } }
    def initialize(count:, seed:, ids:)
      @count = count
      @random = Random.new(seed)
      @ids = ids
    end

    def rows
      Enumerator.new do |yielder|
        (1..@count).each { |number| yielder << row_for(number) }
      end
    end

    private

    def row_for(number)
      first_name = @random.rand(Catalog::FIRST_NAMES.size).then { |i| Catalog::FIRST_NAMES[i] }
      last_name = @random.rand(Catalog::LAST_NAMES.size).then { |i| Catalog::LAST_NAMES[i] }
      country = weighted_pick(Catalog::COUNTRIES)
      department = weighted_pick(Catalog::DEPARTMENTS)
      title = weighted_pick(department[:titles])
      hire_date = Catalog::REFERENCE_DATE - @random.rand(0..MAX_TENURE_DAYS)
      inactive = @random.rand < INACTIVE_SHARE
      spread = 0.9 + ((@random.rand + @random.rand) * 0.1) # bell-shaped, 0.9..1.1

      {
        employee_number: format("E%05d", number),
        first_name: first_name,
        last_name: last_name,
        email: "#{first_name}.#{last_name}.#{number}@acme.example".downcase,
        country_id: @ids.fetch(:countries).fetch(country[:iso_code]),
        department_id: @ids.fetch(:departments).fetch(department[:name]),
        job_title_id: @ids.fetch(:job_titles).fetch(title[:name]),
        hire_date: hire_date,
        status: inactive ? "inactive" : "active",
        salary_amount: local_salary(number:, title:, country:, hire_date:, spread:),
        currency_code: country[:currency_code]
      }
    end

    def local_salary(number:, title:, country:, hire_date:, spread:)
      years = [ (Catalog::REFERENCE_DATE - hire_date) / 365.25, MAX_TENURE_YEARS_COUNTED ].min
      usd = title[:base_usd] * country[:cost_factor] * (1 + (years * TENURE_RAISE_PER_YEAR)) * spread
      usd *= OUTLIER_MULTIPLIER if (number % OUTLIER_EVERY).zero?

      ((usd / RATES_TO_USD.fetch(country[:currency_code])) / SALARY_ROUNDING).round * SALARY_ROUNDING
    end

    def weighted_pick(items)
      roll = @random.rand * items.sum { |item| item[:weight] }
      items.each do |item|
        roll -= item[:weight]
        return item if roll.negative?
      end
      items.last
    end
  end
end
