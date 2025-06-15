class CreateRequestLogs < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists :spree_users, :reset_password_token
    
    create_table_unless_exists :request_logs do |t|
      t.integer :user_id
      t.string :group_name, limit: 60, default: ''
      t.string :method, limit: 12
      t.string :full_url, limit: 700
      t.string :url_path, limit: 160
      t.string :url_params, limit: 640
      t.string :referer_url, limit: 700
      t.timestamps

      t.index :user_id
      t.index :group_name
      t.index :url_path
      t.index :created_at
    end
  end

  def down
    drop_table_if_exists :request_logs
  end
end