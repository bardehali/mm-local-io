class AddBestVariantIdToProducts < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Product.table_name, :best_variant_id, :integer
  end

  def down
    remove_column_if_exists Spree::Product.table_name, :best_variant_id
  end
end
