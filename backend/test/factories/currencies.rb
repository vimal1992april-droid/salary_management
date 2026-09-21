FactoryBot.define do
  factory :currency do
    # Unique three-letter codes: AAB, AAC, ...
    sequence(:code) { |n| [ n / 676 % 26, n / 26 % 26, n % 26 ].map { |i| (65 + i).chr }.join }
    name { "Currency #{code}" }
    rate_to_usd { 1 }
    rate_as_of { Date.new(2026, 1, 1) }
  end
end
