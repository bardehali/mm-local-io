class AddAmountToUserMessages < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists User::Message.table_name, :amount, :float
  end

  def down
    remove_column_if_exists User::Message.table_name, :amount
  end
end
