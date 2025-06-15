class AddIndexOfLastUsedProductIdToTaxonPrices < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::TaxonPrice.table_name, :currency, :string, length: 255, default: 'USD'
    add_column_unless_exists ::Spree::TaxonPrice.table_name, :country_iso, :string, length: 16
    add_index_unless_exists ::Spree::TaxonPrice.table_name, [:taxon_id, :last_used_product_id]
  end

  def down
    remove_column_if_exists ::Spree::TaxonPrice.table_name, :currency
    remove_column_if_exists ::Spree::TaxonPrice.table_name, :country_iso
    remove_index_if_exists ::Spree::TaxonPrice.table_name, [:taxon_id, :last_used_product_id]
  end
end
