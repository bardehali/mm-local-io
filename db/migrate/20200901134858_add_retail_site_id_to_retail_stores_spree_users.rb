class AddRetailSiteIdToRetailStoresSpreeUsers < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :retail_stores_spree_users, :retail_site_id, :integer
    add_index_unless_exists :retail_stores_spree_users, :spree_user_id

    add_index_unless_exists :retail_sites, :user_selectable
    Retail::Site.where(name: %w(aliexpress dhgate) ).update_all(user_selectable: true)
  end

  def down
    remove_column_if_exists :retail_stores_spree_users, :retail_site_id
    remove_column_if_exists :retail_sites, :user_selectable
  end
end
