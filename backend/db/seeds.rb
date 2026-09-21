# Seeds the reference data, a deterministic set of employees (10,000 by default), the HR login and the admin login.
#
#   bin/rails db:seed                      # 10,000 employees
#   SEED_EMPLOYEES=500 bin/rails db:seed   # a smaller set
#   HR_EMAIL=... HR_PASSWORD=... bin/rails db:seed   # choose the HR login
#   ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed   # choose the admin login (the /admin panel)
#
# Safe to run more than once: existing rows are updated or skipped, never duplicated.
count = Integer(ENV.fetch("SEED_EMPLOYEES", Seeding::Runner::DEFAULT_EMPLOYEES))
result = Seeding::Runner.call(employees: count)
puts "Seeded #{result.employees_created} new employees (#{result.employees_total} in total) " \
     "and #{result.salary_changes_created} salary changes."

Seeding::Logins.ensure_from_env!.each { |message| puts message }
