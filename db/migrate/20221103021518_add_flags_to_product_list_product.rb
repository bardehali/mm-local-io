class AddFlagsToProductListProduct < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::ProductListProduct.table_name, :state, :string, length: 60
    add_index_unless_exists Spree::ProductListProduct.table_name, [:product_list_id, :state]
    add_column_unless_exists Spree::ProductListProduct.table_name, :count_or_score, :integer, default: 0
  end

  def down
    remove_index_if_exists Spree::ProductListProduct.table_name, [:product_list_id, :state]
    remove_column_if_exists Spree::ProductListProduct.table_name, :state
    remove_column_if_exists Spree::ProductListProduct.table_name, :count_or_score
  end
end
