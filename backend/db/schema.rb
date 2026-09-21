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

ActiveRecord::Schema[8.1].define(version: 2026_09_21_100004) do
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

  create_table "job_titles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "level", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_job_titles_on_name", unique: true
    t.check_constraint "level >= 1", name: "job_titles_level_positive"
  end

  add_foreign_key "countries", "currencies", column: "currency_code", primary_key: "code"
end
