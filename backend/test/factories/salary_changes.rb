FactoryBot.define do
  factory :salary_change do
    employee
    previous_amount { 80_000 }
    previous_currency_code { employee.currency_code }
    new_amount { 90_000 }
    new_currency_code { employee.currency_code }
    effective_on { Date.new(2024, 4, 1) }
    reason { "Annual review" }
    changed_by factory: :user
  end
end
