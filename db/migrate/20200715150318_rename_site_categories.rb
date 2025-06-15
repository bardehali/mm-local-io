class RenameSiteCategories < ActiveRecord::Migration[6.0]
  def up
    rename_table :site_categories, :retail_site_categories
  end

  def down
    rename_table :retail_site_categories, :site_categories
  end
end
