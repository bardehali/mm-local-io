class ChangeProductLastReviewAtIndex < ActiveRecord::Migration[6.0]
  def up
    remove_index_if_exists :spree_products, [:last_review_at]
    add_index_unless_exists :spree_products, [:deleted_at, :last_review_at]
  end

  def down
    remove_index_if_exists :spree_products, [:deleted_at, :last_review_at]
    add_index_unless_exists :spree_products, [:last_review_at]
  end
end
