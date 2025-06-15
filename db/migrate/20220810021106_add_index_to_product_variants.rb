class AddIndexToProductVariants < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists Spree::Variant.table_name, [:deleted_at, :product_id, :is_master], name:'idx_variants_deleted_product_id_master'
  end

  def down
    remove_index_if_exists Spree::Variant.table_name, [:deleted_at, :product_id, :is_master]
  end
end
