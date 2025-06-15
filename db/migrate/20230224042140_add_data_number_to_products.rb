class AddDataNumberToProducts < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::Product.table_name, :data_number, :string, length: 64, default: nil
  end

  def down
    remove_column_if_exists ::Spree::Product.table_name, :data_number
  end
end
