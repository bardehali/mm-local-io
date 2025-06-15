class AddIndicesToSpreeReviews < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists Spree::Review.table_name, [:product_id, :approved], name: 'idx_reviews_product_id_approved'
    add_index_unless_exists Spree::Review.table_name, [:user_id, :product_id], name: 'idx_reviews_user_id_product_id'
  end

  def down
    remove_column_if_exists Spree::Review.table_name, [:product_id, :approved]
    remove_column_if_exists Spree::Review.table_name, [:user_id, :product_id]
  end
end
