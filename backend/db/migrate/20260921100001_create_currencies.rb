class CreateCurrencies < ActiveRecord::Migration[8.1]
  def change
    # The ISO 4217 code is the natural key, so other tables reference it directly.
    create_table :currencies, id: false do |t|
      t.string :code, limit: 3, null: false, primary_key: true
      t.string :name, null: false
      # Static, dated rate: one unit of this currency in USD.
      t.decimal :rate_to_usd, precision: 18, scale: 8, null: false
      t.date :rate_as_of, null: false

      t.timestamps
    end

    add_check_constraint :currencies, "rate_to_usd > 0", name: "currencies_rate_to_usd_positive"
  end
end
