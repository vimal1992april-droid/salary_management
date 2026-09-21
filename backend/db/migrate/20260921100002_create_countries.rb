class CreateCountries < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :name, null: false
      t.string :iso_code, limit: 2, null: false
      t.string :currency_code, limit: 3, null: false

      t.timestamps
    end

    add_index :countries, :name, unique: true
    add_index :countries, :iso_code, unique: true
    add_index :countries, :currency_code
    add_foreign_key :countries, :currencies, column: :currency_code, primary_key: :code
  end
end
