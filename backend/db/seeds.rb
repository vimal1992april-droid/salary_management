# Seeds the reference data, a deterministic set of employees (10,000 by default) and the HR login.
#
#   bin/rails db:seed                      # 10,000 employees
#   SEED_EMPLOYEES=500 bin/rails db:seed   # a smaller set
#   HR_EMAIL=... HR_PASSWORD=... bin/rails db:seed   # choose the HR login
#
# Safe to run more than once: existing rows are updated or skipped, never duplicated.
count = Integer(ENV.fetch("SEED_EMPLOYEES", Seeding::Runner::DEFAULT_EMPLOYEES))
result = Seeding::Runner.call(employees: count)
puts "Seeded #{result.employees_created} new employees (#{result.employees_total} in total) " \
     "and #{result.salary_changes_created} salary changes."

# Local development gets a known demo login; anywhere else the credentials must be supplied.
hr_email = ENV["HR_EMAIL"].presence || ("hr@acme.example" if Rails.env.development?)
hr_password = ENV["HR_PASSWORD"].presence || ("salary-manager-demo" if Rails.env.development?)

if hr_email && hr_password
  Seeding::HrUser.ensure!(email: hr_email, password: hr_password)
  puts "HR login ready: #{hr_email}"
else
  puts "HR_EMAIL and HR_PASSWORD are not set, so no login was created."
end
