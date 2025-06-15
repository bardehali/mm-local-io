class AddImportedSpreeProductId < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :spree_products, :imported_product_id, :integer
    add_index_unless_exists :spree_products, :imported_product_id
  end

  def down
    remove_column_if_exists :spree_products, :imported_product_id
  end
end
