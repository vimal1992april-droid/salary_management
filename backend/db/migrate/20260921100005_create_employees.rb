class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.references :country, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      t.references :job_title, null: false, foreign_key: true
      t.date :hire_date, null: false
      t.string :status, null: false, default: "active"
      # Current annual gross base salary in `currency_code` (history lives in salary_changes).
      t.decimal :salary_amount, precision: 14, scale: 2, null: false
      t.string :currency_code, limit: 3, null: false

      t.timestamps
    end

    add_index :employees, :employee_number, unique: true
    add_index :employees, :email, unique: true
    add_index :employees, :currency_code
    add_foreign_key :employees, :currencies, column: :currency_code, primary_key: :code
    add_check_constraint :employees, "salary_amount > 0", name: "employees_salary_amount_positive"
    add_check_constraint :employees, "status IN ('active', 'inactive')", name: "employees_status_valid"
  end
end
