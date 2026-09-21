FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Country #{n}" }
    # Unique two-letter codes: AB, AC, ...
    sequence(:iso_code) { |n| [ n / 26 % 26, n % 26 ].map { |i| (65 + i).chr }.join }
    currency
  end
end
