# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_21_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "countries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.string "iso_code", limit: 2, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_code"], name: "index_countries_on_currency_code"
    t.index ["iso_code"], name: "index_countries_on_iso_code", unique: true
    t.index ["name"], name: "index_countries_on_name", unique: true
  end

  create_table "currencies", primary_key: "code", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.date "rate_as_of", null: false
    t.decimal "rate_to_usd", precision: 18, scale: 8, null: false
    t.datetime "updated_at", null: false
    t.check_constraint "rate_to_usd > 0::numeric", name: "currencies_rate_to_usd_positive"
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_departments_on_name", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.bigint "department_id", null: false
    t.string "email", null: false
    t.string "employee_number", null: false
    t.string "first_name", null: false
    t.date "hire_date", null: false
    t.bigint "job_title_id", null: false
    t.string "last_name", null: false
    t.decimal "salary_amount", precision: 14, scale: 2, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_employees_on_country_id"
    t.index ["currency_code"], name: "index_employees_on_currency_code"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["employee_number"], name: "index_employees_on_employee_number", unique: true
    t.index ["job_title_id"], name: "index_employees_on_job_title_id"
    t.check_constraint "salary_amount > 0::numeric", name: "employees_salary_amount_positive"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text])", name: "employees_status_valid"
  end

  create_table "job_titles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "level", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_job_titles_on_name", unique: true
    t.check_constraint "level >= 1", name: "job_titles_level_positive"
  end

  create_table "salary_changes", force: :cascade do |t|
    t.bigint "changed_by_id"
    t.datetime "created_at", null: false
    t.date "effective_on", null: false
    t.bigint "employee_id", null: false
    t.decimal "new_amount", precision: 14, scale: 2, null: false
    t.string "new_currency_code", limit: 3, null: false
    t.decimal "previous_amount", precision: 14, scale: 2, null: false
    t.string "previous_currency_code", limit: 3, null: false
    t.string "reason", limit: 500, null: false
    t.datetime "updated_at", null: false
    t.index ["changed_by_id"], name: "index_salary_changes_on_changed_by_id"
    t.index ["employee_id", "effective_on"], name: "index_salary_changes_on_employee_id_and_effective_on"
    t.index ["employee_id"], name: "index_salary_changes_on_employee_id"
    t.check_constraint "new_amount > 0::numeric", name: "salary_changes_new_amount_positive"
    t.check_constraint "previous_amount > 0::numeric", name: "salary_changes_previous_amount_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "countries", "currencies", column: "currency_code", primary_key: "code"
  add_foreign_key "employees", "countries"
  add_foreign_key "employees", "currencies", column: "currency_code", primary_key: "code"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "job_titles"
  add_foreign_key "salary_changes", "currencies", column: "new_currency_code", primary_key: "code"
  add_foreign_key "salary_changes", "currencies", column: "previous_currency_code", primary_key: "code"
  add_foreign_key "salary_changes", "employees"
  add_foreign_key "salary_changes", "users", column: "changed_by_id"
  add_foreign_key "sessions", "users"
end
