class CreateApiRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :api_requests do |t|
      t.string :http_method, null: false, limit: 10
      t.string :path, null: false
      t.string :route
      t.text :query_string
      t.integer :status, null: false
      t.decimal :duration_ms, null: false, precision: 10, scale: 2
      t.bigint :user_id # not a foreign key: a recorded call outlives the person who made it
      t.string :ip_address
      t.string :request_content_type
      t.text :request_body
      t.boolean :request_truncated, null: false, default: false
      t.string :response_content_type
      t.text :response_body
      t.boolean :response_truncated, null: false, default: false
      t.datetime :created_at, null: false, precision: 6 # written once, never updated
    end

    add_index :api_requests, :created_at
    add_index :api_requests, %i[http_method route]
    add_index :api_requests, :status
    add_index :api_requests, :user_id
  end
end
