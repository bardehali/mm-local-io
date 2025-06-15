class CreateSearchLogs < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :search_logs do |t|
      t.string :keywords, length: 100
      t.string :other_params, length: 640
      t.integer :user_id
      t.string :ip, length: 64
      t.string :country, length: 64
      t.string :city, length: 64
      t.string :state, length: 128
      t.string :state_iso_code, length: 32
      t.string :zip_code, length: 64
      t.float :latitude
      t.float :longitude
      t.timestamps

      t.index :keywords
      t.index :user_id
      t.index :created_at
    end
  end

  def down
    drop_table_if_exists :search_logs
  end
end
