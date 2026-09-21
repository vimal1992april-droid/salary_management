FactoryBot.define do
  factory :employee do
    sequence(:employee_number) { |n| format("E%05d", n) }
    first_name { "Asha" }
    last_name { "Verma" }
    sequence(:email) { |n| "employee#{n}@acme.example" }
    country
    department
    job_title
    currency { country.currency }
    hire_date { Date.new(2022, 3, 1) }
    salary_amount { 90_000 }
  end
end
