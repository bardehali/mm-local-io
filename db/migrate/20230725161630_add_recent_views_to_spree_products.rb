class AddRecentViewsToSpreeProducts < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Product.table_name, :recent_view_count, :integer, default: 0
    add_index_unless_exists Spree::Product.table_name, :recent_view_count
  end

  def down
    remove_index_if_exists Spree::Product.table_name, :recent_view_count
    remove_column_if_exists Spree::Product.table_name, :recent_view_count
  end
end
