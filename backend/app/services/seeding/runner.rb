module Seeding
  # Loads the reference data, then generates and inserts employees in batches.
  # Safe to run repeatedly: employees are keyed on their employee number.
  class Runner
    DEFAULT_EMPLOYEES = 10_000
    DEFAULT_SEED = 42
    DEFAULT_BATCH_SIZE = 1_000

    Result = Struct.new(:employees_created, :employees_total)

    def self.call(**options)
      new(**options).call
    end

    def initialize(employees: DEFAULT_EMPLOYEES, seed: DEFAULT_SEED, batch_size: DEFAULT_BATCH_SIZE)
      @employees = employees
      @seed = seed
      @batch_size = batch_size
    end

    def call
      ReferenceData.load!
      before = Employee.count

      generator.rows.each_slice(@batch_size) do |batch|
        Employee.insert_all(batch, unique_by: :employee_number, returning: false)
      end

      Result.new(Employee.count - before, Employee.count)
    end

    private

    def generator
      EmployeeGenerator.new(count: @employees, seed: @seed, ids: reference_ids)
    end

    def reference_ids
      {
        countries: Country.pluck(:iso_code, :id).to_h,
        departments: Department.pluck(:name, :id).to_h,
        job_titles: JobTitle.pluck(:name, :id).to_h
      }
    end
  end
end
