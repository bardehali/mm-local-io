class AddUserSelectableToRetailSites < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :retail_sites, :user_selectable, :boolean, default: true
    add_column_unless_exists :retail_sites, :position, :integer, default: 0
    add_index_unless_exists :retail_sites, :position

    Retail::Site.where("name NOT IN ('aliexpress','dhgate')").update_all(user_selectable: false)
  end

  def down
    remove_column_if_exists :retail_sites, :user_selectable
    remove_column_if_exists :retail_sites, :position
  end
end
