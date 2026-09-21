FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "hr#{n}@acme.example" }
    password { "correct-horse-battery" }
  end
end
