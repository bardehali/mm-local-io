class AddDisplayVariantAdoptionId < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Product.table_name, :display_variant_adoption_id, :integer, default: nil
    add_index_unless_exists Spree::Product.table_name, :display_variant_adoption_id
  end

  def down
    remove_index_if_exists Spree::Product.table_name, :display_variant_adoption_id
    remove_column_if_exists Spree::Product.table_name, :display_variant_adoption_id
  end
end
