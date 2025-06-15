class CreateUserStats < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :user_stats do |t|
      t.integer :user_id, null: false
      t.string  :name, length: 64
      t.string  :value, length: 255
      t.timestamps
      t.index [:user_id]
      t.index [:user_id, :name]
    end
  end

  def down
    drop_table_if_exists :user_stats
  end
end
