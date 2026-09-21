module Seeding
  # Static description of the fictional ACME organisation used by the seed.
  #
  # `cost_factor` scales US pay for a country's labour market and `weight` is its
  # share of headcount. Job titles carry a base annual salary in USD for a US
  # employee; the generator applies the country factor, tenure and some spread.
  module Catalog
    # "Today" for generating hire dates, so the seed never depends on the clock.
    REFERENCE_DATE = Date.new(2026, 9, 1)
    RATES_AS_OF = Date.new(2026, 1, 1)

    CURRENCIES = [
      { code: "USD", name: "US Dollar", rate_to_usd: "1" },
      { code: "GBP", name: "Pound Sterling", rate_to_usd: "1.27" },
      { code: "EUR", name: "Euro", rate_to_usd: "1.08" },
      { code: "INR", name: "Indian Rupee", rate_to_usd: "0.012" },
      { code: "JPY", name: "Japanese Yen", rate_to_usd: "0.0067" },
      { code: "BRL", name: "Brazilian Real", rate_to_usd: "0.19" },
      { code: "CAD", name: "Canadian Dollar", rate_to_usd: "0.73" },
      { code: "AUD", name: "Australian Dollar", rate_to_usd: "0.66" }
    ].freeze

    COUNTRIES = [
      { name: "United States", iso_code: "US", currency_code: "USD", cost_factor: 1.00, weight: 30 },
      { name: "India", iso_code: "IN", currency_code: "INR", cost_factor: 0.28, weight: 22 },
      { name: "United Kingdom", iso_code: "GB", currency_code: "GBP", cost_factor: 0.80, weight: 10 },
      { name: "Germany", iso_code: "DE", currency_code: "EUR", cost_factor: 0.85, weight: 10 },
      { name: "Brazil", iso_code: "BR", currency_code: "BRL", cost_factor: 0.35, weight: 8 },
      { name: "Canada", iso_code: "CA", currency_code: "CAD", cost_factor: 0.90, weight: 8 },
      { name: "Japan", iso_code: "JP", currency_code: "JPY", cost_factor: 0.75, weight: 6 },
      { name: "Australia", iso_code: "AU", currency_code: "AUD", cost_factor: 0.90, weight: 6 }
    ].freeze

    DEPARTMENTS = [
      {
        name: "Engineering", weight: 35, titles: [
          { name: "Software Engineer I", level: 1, base_usd: 95_000, weight: 30 },
          { name: "Software Engineer II", level: 2, base_usd: 120_000, weight: 30 },
          { name: "Senior Software Engineer", level: 3, base_usd: 155_000, weight: 22 },
          { name: "Staff Engineer", level: 4, base_usd: 195_000, weight: 8 },
          { name: "Engineering Manager", level: 4, base_usd: 190_000, weight: 10 }
        ]
      },
      {
        name: "Product", weight: 8, titles: [
          { name: "Associate Product Manager", level: 1, base_usd: 100_000, weight: 25 },
          { name: "Product Manager", level: 2, base_usd: 135_000, weight: 40 },
          { name: "Senior Product Manager", level: 3, base_usd: 165_000, weight: 27 },
          { name: "Director of Product", level: 5, base_usd: 220_000, weight: 8 }
        ]
      },
      {
        name: "Design", weight: 6, titles: [
          { name: "Product Designer", level: 2, base_usd: 110_000, weight: 50 },
          { name: "Senior Product Designer", level: 3, base_usd: 140_000, weight: 35 },
          { name: "Design Lead", level: 4, base_usd: 165_000, weight: 15 }
        ]
      },
      {
        name: "Sales", weight: 18, titles: [
          { name: "Sales Development Representative", level: 1, base_usd: 65_000, weight: 35 },
          { name: "Account Executive", level: 2, base_usd: 95_000, weight: 35 },
          { name: "Senior Account Executive", level: 3, base_usd: 125_000, weight: 20 },
          { name: "Sales Manager", level: 4, base_usd: 150_000, weight: 10 }
        ]
      },
      {
        name: "Marketing", weight: 8, titles: [
          { name: "Marketing Associate", level: 1, base_usd: 62_000, weight: 45 },
          { name: "Marketing Manager", level: 3, base_usd: 110_000, weight: 45 },
          { name: "Head of Marketing", level: 5, base_usd: 170_000, weight: 10 }
        ]
      },
      {
        name: "Customer Support", weight: 15, titles: [
          { name: "Support Specialist", level: 1, base_usd: 52_000, weight: 55 },
          { name: "Senior Support Specialist", level: 2, base_usd: 68_000, weight: 30 },
          { name: "Support Team Lead", level: 3, base_usd: 85_000, weight: 15 }
        ]
      },
      {
        name: "Finance", weight: 5, titles: [
          { name: "Financial Analyst", level: 2, base_usd: 85_000, weight: 50 },
          { name: "Senior Financial Analyst", level: 3, base_usd: 108_000, weight: 35 },
          { name: "Finance Manager", level: 4, base_usd: 140_000, weight: 15 }
        ]
      },
      {
        name: "People Operations", weight: 5, titles: [
          { name: "HR Coordinator", level: 1, base_usd: 55_000, weight: 45 },
          { name: "HR Business Partner", level: 3, base_usd: 95_000, weight: 40 },
          { name: "HR Manager", level: 4, base_usd: 120_000, weight: 15 }
        ]
      }
    ].freeze

    FIRST_NAMES = %w[
      Aarav Aditi Akira Alice Amelia Ananya Andre Arjun Beatriz Carlos Chloe Daniel Diego Elena Emma Erik
      Fatima Gabriel Hana Hiroshi Isabella Ishaan Jack Jasmine Kavya Kenji Lars Liam Lucas Maria Mateo
      Meera Mia Noah Olivia Priya Rohan Sakura Sofia Sophie Thomas Yuki
    ].freeze

    LAST_NAMES = %w[
      Almeida Anderson Bose Brown Chen Costa Das Davies Fischer Garcia Gupta Hansen Ito Iyer Jain Johnson
      Kapoor Khan Kim Kumar Lopez Martin Meyer Mishra Miller Murphy Nair Nakamura Novak Oliveira Patel
      Reddy Rossi Santos Sato Schmidt Sharma Singh Smith Suzuki Taylor Verma Williams Wilson
    ].freeze
  end
end
