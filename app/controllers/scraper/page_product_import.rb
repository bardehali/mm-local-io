class Scraper::PageProductImport < ::ApplicationRecord
  self.table_name = 'scraper_page_product_imports'

  belongs_to :import_run, class_name:'Scraper::ImportRun', foreign_key:'scraper_import_run_id'
  belongs_to :page, class_name:'Scraper::Page', foreign_key:'scraper_page_id'

  belongs_to :product, -> { with_deleted }, class_name:'Spree::Product', foreign_key:'spree_product_id'
end