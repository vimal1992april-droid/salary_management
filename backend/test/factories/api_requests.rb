FactoryBot.define do
  factory :api_request do
    http_method { "GET" }
    path { "/api/employees" }
    route { "/api/employees" }
    status { 200 }
    duration_ms { 12.5 }
    created_at { Time.current }
  end
end
