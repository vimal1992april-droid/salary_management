# Times the API endpoints over real HTTP against a running server with the seeded database, and prints
# a Markdown table. Used to check the "responds in under ~300 ms with 10,000 employees" target; the
# results are recorded in docs/performance.md.
#
#   bin/rails db:seed
#   bin/rails server                      # in another terminal
#   ruby script/benchmark.rb              # 30 timed runs per endpoint
#   RUNS=100 BASE_URL=http://localhost:3000 ruby script/benchmark.rb
#
# It is a plain HTTP client (no Rails is loaded), so it can be pointed at any deployment. A development
# server reloads code between requests, so its numbers are slightly pessimistic for production.
require "json"
require "net/http"
require "uri"

BASE = URI(ENV.fetch("BASE_URL", "http://localhost:3000"))
RUNS = Integer(ENV.fetch("RUNS", 30))
EMAIL = ENV.fetch("HR_EMAIL", "hr@acme.example")
PASSWORD = ENV.fetch("HR_PASSWORD", "salary-manager-demo")

def clock
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def percentile(sorted, fraction)
  sorted[((sorted.size - 1) * fraction).ceil]
end

def size_label(bytes)
  bytes >= 1024 * 1024 ? format("%.1f MB", bytes / 1024.0 / 1024) : format("%.0f KB", bytes / 1024.0)
end

http = Net::HTTP.new(BASE.host, BASE.port)
http.use_ssl = BASE.scheme == "https"
http.start

login = Net::HTTP::Post.new("/api/session", "Content-Type" => "application/json")
login.body = { email: EMAIL, password: PASSWORD }.to_json
response = http.request(login)
abort "Login failed (#{response.code}); run bin/rails db:seed and check HR_EMAIL/HR_PASSWORD." unless response.code == "201"
cookie = response.get_fields("set-cookie").map { |field| field.split(";").first }.join("; ")

get = lambda do |path|
  http.request(Net::HTTP::Get.new(path, "Cookie" => cookie, "Accept" => "application/json"))
end

# IDs come from the API itself, so the script works against any seeded deployment.
lookups = JSON.parse(get.call("/api/lookups").body)
india = lookups["countries"].find { |country| country["iso_code"] == "IN" }
sales = lookups["departments"].find { |department| department["name"] == "Sales" }
total = JSON.parse(get.call("/api/employees?per_page=1").body).dig("meta", "total")
with_history = (1..200).find { |id| JSON.parse(get.call("/api/employees/#{id}/salary_changes").body)["data"]&.any? }

endpoints = {
  "Directory, first page" => "/api/employees",
  "Directory, text search (\"priya\")" => "/api/employees?q=priya",
  "Directory, two-word search (\"priya nair\")" => "/api/employees?q=priya+nair",
  "Directory, filters + sort by hire date" =>
    "/api/employees?country_id=#{india&.fetch('id')}&department_id=#{sales&.fetch('id')}&status=active&sort=hire_date",
  "Directory, sort by salary (USD), 100 per page" => "/api/employees?sort=salary&direction=desc&per_page=100",
  "Directory, sort by country name, 100 per page" => "/api/employees?sort=country&per_page=100",
  "Directory, last page" => "/api/employees?page=#{(total / 25.0).ceil}",
  "Lookups" => "/api/lookups",
  "Insights, overview" => "/api/insights/overview",
  "Insights, pay stats by country" => "/api/insights/salary_stats?group_by=country",
  "Insights, pay stats by department" => "/api/insights/salary_stats?group_by=department",
  "Insights, pay stats by job title" => "/api/insights/salary_stats?group_by=job_title",
  "Insights, distribution (12 buckets)" => "/api/insights/distribution?bucket_count=12",
  "Insights, top earners" => "/api/insights/top_earners?limit=10",
  "Insights, outliers" => "/api/insights/outliers?limit=25",
  "CSV export, all employees" => "/api/employees/export",
  "Salary history of one employee" => "/api/employees/#{with_history}/salary_changes"
}

puts "Server: #{BASE}, #{total} employees, #{RUNS} timed runs per endpoint after 1 warm-up, over real HTTP"
puts
puts "| Endpoint | p50 (ms) | p95 (ms) | max (ms) | Response |"
puts "|---|---:|---:|---:|---:|"

endpoints.each do |label, path|
  warm = get.call(path)
  abort "#{label}: got #{warm.code} for #{path}" unless warm.code == "200"

  timings = Array.new(RUNS) do
    started = clock
    get.call(path)
    (clock - started) * 1000
  end.sort

  puts format("| %s | %.0f | %.0f | %.0f | %s |", label, percentile(timings, 0.5), percentile(timings, 0.95),
              timings.last, size_label(warm.body.bytesize))
end
