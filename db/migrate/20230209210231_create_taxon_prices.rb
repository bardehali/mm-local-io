class CreateTaxonPrices < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_taxon_prices do |t|
      t.integer :taxon_id, null: false
      t.float :price, null: false
      t.integer :last_used_product_id
    end
    add_index_unless_exists :spree_taxon_prices, :taxon_id

    add_column_unless_exists :spree_adoption_prices, :previous_amount, :float
    add_column_unless_exists :spree_adoption_prices, :boundary_difference, :float, default: 0.0
  end

  def down
    drop_table_if_exists :spree_taxon_prices

    remove_column_if_exists :spree_adoption_prices, :previous_amount
    remove_column_if_exists :spree_adoption_prices, :boundary_difference
  end
end
