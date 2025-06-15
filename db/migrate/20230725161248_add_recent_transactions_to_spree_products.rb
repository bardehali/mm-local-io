class AddRecentTransactionsToSpreeProducts < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Product.table_name, :recent_transaction_count, :integer, default: 0
    add_index_unless_exists Spree::Product.table_name, :recent_transaction_count
  end

  def down
    remove_index_if_exists Spree::Product.table_name, :recent_transaction_count
    remove_column_if_exists Spree::Product.table_name, :recent_transaction_count
  end
end
