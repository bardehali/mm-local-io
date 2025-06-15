class AddRepVariantIdAndRepVariantSetByAdmin < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Product.table_name, :rep_variant_id, :integer
    add_column_unless_exists Spree::Product.table_name, :rep_variant_set_by_admin_at, :datetime
  end

  def down
    remove_column_if_exists Spree::Product.table_name, :rep_variant_id
    remove_column_if_exists Spree::Product.table_name, :rep_variant_set_by_admin_at
  end
end
