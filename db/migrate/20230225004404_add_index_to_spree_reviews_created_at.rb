class AddIndexToSpreeReviewsCreatedAt < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists ::Spree::Review.table_name, [:product_id, :created_at]
  end

  def down
    remove_index_if_exists ::Spree::Review.table_name, [:product_id, :created_at]
  end
end
