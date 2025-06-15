class CreateMessages < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :user_messages do |t|
      t.string :type, limit: 64, default: 'Users::Message'
      t.integer :sender_user_id, null: false
      t.integer :recipient_user_id, null: false
      t.text :comment
      t.string :record_type, limit: 64
      t.integer :record_id
      t.string :group_name, limit: 64
      t.integer :level, default: 100
      t.text :references
      t.integer :parent_message_id

      t.timestamps
      t.datetime :last_viewed_at
      t.datetime :deleted_at

      t.index [:sender_user_id, :deleted_at]
      t.index [:recipient_user_id, :deleted_at]
      t.index [:recipient_user_id, :last_viewed_at]
      t.index [:record_type, :record_id]
      t.index :parent_message_id
      t.index :level
    end

    add_index_unless_exists :spree_orders, [:seller_user_id, :completed_at]
  end

  def down
    drop_table_if_exists :user_messages
  end
end
