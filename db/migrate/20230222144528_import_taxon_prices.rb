class ImportTaxonPrices < ActiveRecord::Migration[6.0]
  def change
    puts "Populate spree_taxon_prices (Spree::TaxonPrice)"
    Spree::TaxonPrice.import_from_csv
  end
end
