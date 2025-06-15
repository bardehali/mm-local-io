class AddCanonicalCodeToSpreeProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_products, :canonical_code, :string
  end
end
