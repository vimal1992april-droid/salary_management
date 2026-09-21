module Seeding
  # Loads currencies, countries, departments and job titles from the catalog.
  # Idempotent: rows are upserted on their natural key, so re-running updates in place.
  module ReferenceData
    module_function

    def load!
      Currency.upsert_all(
        Catalog::CURRENCIES.map { |currency| currency.merge(rate_as_of: Catalog::RATES_AS_OF) }
      )
      Country.upsert_all(
        Catalog::COUNTRIES.map { |country| country.slice(:name, :iso_code, :currency_code) },
        unique_by: :iso_code
      )
      Department.upsert_all(
        Catalog::DEPARTMENTS.map { |department| department.slice(:name) },
        unique_by: :name
      )
      JobTitle.upsert_all(
        Catalog::DEPARTMENTS.flat_map { |department| department[:titles] }.map { |title| title.slice(:name, :level) },
        unique_by: :name
      )
    end
  end
end
