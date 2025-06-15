class CreateScraperTables < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :scraper_pages do |t|
      t.string  :page_type, limit: 64
      t.integer :retail_site_id, null: false
      t.integer :retail_store_id
      t.string  :title, limit: 191
      t.string  :page_url, limit: 360, null: false
      t.string  :url_path, limit: 120
      t.string  :url_params, limit: 240
      t.integer :page_number, default: 1
      t.integer :referrer_page_id
      t.integer :root_referrer_page_id
      t.string  :file_path, limit: 240
      t.string  :file_status, limit: 20, default: 'NOT_FETCHED'
      t.timestamps

      t.index :page_type
      t.index :retail_site_id
      t.index [:retail_site_id, :retail_store_id], name:'idx_scraper_pages_retail_site_store'
      t.index [:retail_site_id, :url_path, :url_params], name:'idx_scraper_pages_retail_site_url_params'
      t.index [:url_path, :url_params], name:'idx_scraper_pages_url_path_params'
      t.index :referrer_page_id
      t.index :created_at
      t.index :file_status
    end

    create_table_unless_exists :scraper_pages_spree_products do|t|
      t.integer :scraper_page_id
      t.integer :spree_product_id
      t.integer :scraper_import_run_id
      t.timestamps

      t.index :scraper_page_id
      t.index [:scraper_import_run_id, :scraper_page_id], name:'idx_spsp_import_run_page_ids'
      t.index :spree_product_id
    end

    create_table_unless_exists :scraper_import_runs do|t|
      t.integer :retail_site_id, null: false
      t.integer :retail_store_id
      t.string  :name, limit: 64
      t.string  :initial_url, limit: 240
      t.integer :initiator_user_id
      t.string  :status, limit: 64, default: 'NEW'
      t.string  :keywords, limit: 64
      t.timestamps

      t.index :retail_site_id, name: 'idx_sir_retail_site_id'
      t.index :retail_store_id, name: 'idx_sir_retail_store_id'
      t.index :initiator_user_id, name: 'idx_initiator_user_id'
      t.index :status
    end

    create_table_unless_exists :scraper_import_runs_pages do|t|
      t.integer :scraper_import_run_id, null: false
      t.integer :scraper_page_id, null: false

      t.index :scraper_import_run_id, name: 'idx_sirp_scraper_import_run_id'
      t.index :scraper_page_id, name: 'idx_sirp_scraper_page_id'
    end

    create_table_unless_exists :scraper_runs do|t|
      t.integer :retail_site_id, null: false
      t.string  :title, limit: 160
      t.string  :running_server, limit: 160
      t.string  :initial_url, limit: 160, default: '/'
      t.string  :user_agent, limit: 160
      t.text    :cookie
      t.timestamps
      t.datetime :last_run_at

      t.index :retail_site_id
      t.index :running_server
      t.index :created_at
    end
  end

  def down
    [:scraper_pages, :scraper_pages_spree_products, :scraper_import_runs, 
      :scraper_import_runs_pages, :scraper_runs].each do|table_name|
        drop_table_if_exists table_name
      end
  end
end
