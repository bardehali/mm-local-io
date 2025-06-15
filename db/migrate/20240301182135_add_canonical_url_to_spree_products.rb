class AddCanonicalUrlToSpreeProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_products, :canonical_url, :string
  end
end
