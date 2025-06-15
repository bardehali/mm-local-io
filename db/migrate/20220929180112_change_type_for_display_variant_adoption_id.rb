class ChangeTypeForDisplayVariantAdoptionId < ActiveRecord::Migration[6.0]
  def up
    remove_index_if_exists ::Spree::Product.table_name, :display_variant_adoption_id
    remove_column_if_exists ::Spree::Product.table_name, :display_variant_adoption_id
    
    add_column_unless_exists ::Spree::Product.table_name, :display_variant_adoption_code, :string, length: 40
    add_column_unless_exists ::Spree::VariantAdoption.table_name, :code, :string, length: 40
    add_index_unless_exists ::Spree::VariantAdoption.table_name, :code
  end

  def down
    add_column_unless_exists ::Spree::Product.table_name, :display_variant_adoption_id, :integer
    add_index_unless_exists ::Spree::Product.table_name, :display_variant_adoption_id

    remove_column_if_exists ::Spree::Product.table_name, :display_variant_adoption_code
    remove_index_if_exists ::Spree::VariantAdoption.table_name, :code
    remove_column_if_exists ::Spree::VariantAdoption.table_name, :code
  end
end
