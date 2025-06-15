class CreateSpreeUserSellingTaxons < ActiveRecord::Migration[6.0]
  def change
    create_table_unless_exists :spree_user_selling_taxons do |t|
      t.integer :user_id
      t.integer :taxon_id
      t.index :user_id
    end
  end
end
