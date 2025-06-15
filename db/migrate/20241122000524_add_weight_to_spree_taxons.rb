class AddWeightToSpreeTaxons < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_taxons, :weight, :decimal, precision: 8, scale: 2, default: 0.0, null: false
  end
end
