FactoryBot.define do
  factory :job_title do
    sequence(:name) { |n| "Job title #{n}" }
    level { 1 }
  end
end
