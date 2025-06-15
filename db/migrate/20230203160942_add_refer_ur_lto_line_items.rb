class AddReferUrLtoLineItems < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::LineItem.table_name, :referer_url, :string, length: 1000
  end

  def down
    remove_column_if_exists Spree::LineItem.table_name, :referer_url
  end
end
