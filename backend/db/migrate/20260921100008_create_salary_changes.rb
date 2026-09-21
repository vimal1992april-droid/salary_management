class CreateSalaryChanges < ActiveRecord::Migration[8.1]
  def change
    # Append-only history: a change is never edited, a correction is a new change.
    create_table :salary_changes do |t|
      t.references :employee, null: false, foreign_key: true
      t.decimal :previous_amount, precision: 14, scale: 2, null: false
      t.string :previous_currency_code, limit: 3, null: false
      t.decimal :new_amount, precision: 14, scale: 2, null: false
      t.string :new_currency_code, limit: 3, null: false
      t.date :effective_on, null: false
      t.string :reason, limit: 500, null: false
      # Nullable on purpose: history that was imported or seeded has no author.
      t.references :changed_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :salary_changes, %i[employee_id effective_on]
    add_foreign_key :salary_changes, :currencies, column: :previous_currency_code, primary_key: :code
    add_foreign_key :salary_changes, :currencies, column: :new_currency_code, primary_key: :code
    add_check_constraint :salary_changes, "previous_amount > 0", name: "salary_changes_previous_amount_positive"
    add_check_constraint :salary_changes, "new_amount > 0", name: "salary_changes_new_amount_positive"
  end
end
