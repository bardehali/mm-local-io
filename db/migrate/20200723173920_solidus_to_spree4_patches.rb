##
# Adaptations from Solidus/Spree 3 database to schema of Spree 4 tables.
# Has the necessary checks, such as add column unless exists.
class SolidusToSpree4Patches < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :friendly_id_slugs, :deleted_at, :datetime
    add_index_unless_exists :friendly_id_slugs, :deleted_at

    if table_exists?('site_categories')
      drop_table_if_exists :retail_site_categories
      rename_table :site_categories, :retail_site_categories
    end

    add_column_unless_exists :spree_payment_methods, :display_on, :string, limit: 255
    add_column_unless_exists :spree_payment_methods, :store_id, :integer

    add_column_unless_exists :spree_products, :discontinue_on, :datetime
    add_index_unless_exists :spree_products, :discontinue_on

    if table_exists?('spree_roles_users')
      drop_table_if_exists :spree_role_users
      rename_table :spree_roles_users, :spree_role_users
    end

    %w(facebook twitter instagram).each do|site|
      add_column_unless_exists :spree_stores, site.to_sym, :string, limit: 255
    end

    Spree::Store.where("default_currency='US' OR default_currency=''").update_all(default_currency: nil)

    add_column_unless_exists :spree_taxons, :hide_from_nav, :boolean, default: false

  end
end
