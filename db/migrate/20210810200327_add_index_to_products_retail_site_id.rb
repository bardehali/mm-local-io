class AddIndexToProductsRetailSiteId < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists :spree_products, [:deleted_at, :retail_site_id]
  end

  def down
    remove_index_if_exists :spree_products, [:deleted_at, :retail_site_id]
  end
end
