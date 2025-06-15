# This migration comes from spree_reviews (originally 20210728110635)
class ChangeProductIdAndUserIdTypeForSpreeReviews < ActiveRecord::Migration[4.2]
  def change
    change_table(:spree_reviews) do |t|
      t.change :product_id, :bigint
      t.change :user_id, :bigint
    end
  end
end
