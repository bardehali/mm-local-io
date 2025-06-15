class AddDeletedAtToVariantAdoptions < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::VariantAdoption.table_name, :deleted_at, :datetime, default: nil
    add_index_unless_exists ::Spree::VariantAdoption.table_name, [:variant_id, :deleted_at], name:'idx_variant_adoptions_variant_id_deleted_at'
  end

  def down
    remove_index_if_exists ::Spree::VariantAdoption.table_name, [:variant_id, :deleted_at]
    remove_column_if_exists ::Spree::VariantAdoption.table_name, :deleted_at
  end
end
