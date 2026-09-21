# Seeds the reference data and a deterministic set of employees (10,000 by default).
#
#   bin/rails db:seed                      # 10,000 employees
#   SEED_EMPLOYEES=500 bin/rails db:seed   # a smaller set
#
# Safe to run more than once: existing rows are updated or skipped, never duplicated.
count = Integer(ENV.fetch("SEED_EMPLOYEES", Seeding::Runner::DEFAULT_EMPLOYEES))
result = Seeding::Runner.call(employees: count)

puts "Seeded #{result.employees_created} new employees (#{result.employees_total} in total)."
