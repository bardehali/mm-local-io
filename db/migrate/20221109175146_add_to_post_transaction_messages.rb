class AddToPostTransactionMessages < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists User::Message.table_name, :admin_last_viewed_at, :datetime
    add_index_unless_exists User::Message.table_name, [:type, :admin_last_viewed_at]
  end

  def down
    remove_index_if_exists User::Message.table_name, [:type, :admin_last_viewed_at]
    remove_column_if_exists User::Message.table_name, :admin_last_viewed_at
  end
end
