class AddRetailTables < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :retail_sites do|t|
      t.string :name, limit: 80, null: false
      t.string :domain, limit: 100
      t.string :initial_url, limit: 160, default: '/'
      t.string :site_scraper, limit: 160
      t.timestamps

      t.index :domain, name: 'rs_domain_index'
      t.index :created_at, name: 'rs_created_at_index'
    end

    add_index_unless_exists :retail_sites, :name

    create_table_unless_exists :retail_stores do|t|
      t.string :name, limit: 80
      t.integer :retail_site_id
      t.string :store_url, limit: 160
      t.integer :retail_site_store_id

      t.index :retail_site_id, name:'rstore_site_id_index'
      t.index :retail_site_store_id, name:'rstore_site_store_id_index'
    end

    create_table_unless_exists :retail_stores_spree_users do|t|
      t.integer :retail_store_id, null: false
      t.integer :spree_user_id, null: false
      t.index :retail_store_id, name:'idex_rssu_on_retail_store_id'
    end

    create_table_unless_exists :site_categories do|t|
      t.string :site_name, limit: 255
      t.integer :other_site_category_id
      t.integer :mapped_taxon_id
      t.integer :parent_id
      t.integer :position, default: 1
      t.string :name, limit: 255
      t.integer :lft
      t.integer :rgt
      t.integer :depth, default: 0
      t.integer :retail_site_id
      t.timestamps

      t.index :site_name
      t.index :parent_id
      t.index :position
      t.index :lft
      t.index :rgt
      t.index :retail_site_id
      t.index [:retail_site_id, :name], name: 'idx_site_categories_retail_site_id_name'
    end
  end
end
