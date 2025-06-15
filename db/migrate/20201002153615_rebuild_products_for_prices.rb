class RebuildProductsForPrices < ActiveRecord::Migration[6.0]
  def change
    puts "Rebuilding ES index of #{Spree::Product.count} products"
    Spree::Product.es.rebuild_index!
  end
end
