class CreateJobTitles < ActiveRecord::Migration[8.1]
  def change
    create_table :job_titles do |t|
      t.string :name, null: false
      t.integer :level, null: false

      t.timestamps
    end

    add_index :job_titles, :name, unique: true
    add_check_constraint :job_titles, "level >= 1", name: "job_titles_level_positive"
  end
end
