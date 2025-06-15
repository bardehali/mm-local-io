class AddOldFilePathAndNameToAssets < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :spree_assets, :old_filepath, :string, limit: 512
    add_column_unless_exists :spree_assets, :filename, :string, limit: 128
  end

  def down
    remove_column_if_exists :spree_assets, :old_filepath
    remove_column_if_exists :spree_assets, :filename
  end
end
