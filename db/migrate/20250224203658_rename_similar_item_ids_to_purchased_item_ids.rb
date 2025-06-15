class RenameSimilarItemIdsToPurchasedItemIds < ActiveRecord::Migration[6.0]
  def change
    rename_column :spree_item_reviews, :similar_item_ids, :purchased_item_ids
  end
end
