class AddLastViewedAtToProducts < ActiveRecord::Migration[6.0]
  def change
    add_column_unless_exists :spree_products, :last_viewed_at, :datetime
  end
end
