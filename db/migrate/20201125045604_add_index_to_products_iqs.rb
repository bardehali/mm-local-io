class AddIndexToProductsIqs < ActiveRecord::Migration[6.0]
  def change
    add_index_unless_exists :spree_products, [:deleted_at, :iqs]

    query = Spree::Product.where('last_review_at IS NULL and (iqs IS NULL OR iqs = 0)')
    puts "Count of products to recalculate_status #{query.count}"
    query.each do|p|
      p.recalculate_status!
    end
  end
end
