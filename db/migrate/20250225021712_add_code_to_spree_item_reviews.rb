class AddCodeToSpreeItemReviews < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_item_reviews, :code, :string
    add_index :spree_item_reviews, :code, unique: true
  end
end
