class AddGenderToTaxons < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Taxon.table_name, :genders, :string, length: 80
  end

  def down
    remove_column_if_exists Spree::Taxon.table_name, :genders, :string
  end
end
