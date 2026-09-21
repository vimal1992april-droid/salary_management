FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "hr#{n}@acme.example" }
    password { "correct-horse-battery" }

    # Someone who may open the /admin panel, as well as the HR manager's API.
    trait :admin do
      sequence(:email) { |n| "admin#{n}@acme.example" }
      admin { true }
    end
  end
end
