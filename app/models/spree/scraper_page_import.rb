class Spree::ScraperPageImport < ::ApplicationRecord 
  self.table_name = 'scraper_pages_spree_products'

  belongs_to :scraper_page, foreign_key: 'scraper_page_id', class_name:'Scraper::Page'
  alias_method :page, :scraper_page

  belongs_to :scraper_import_run, class_name:'Scraper::ImportRun', foreign_key: 'scraper_import_run_id', optional: true
  alias_method :import_run, :scraper_import_run

  has_and_belongs_to_many :import_runs, class_name:'Scraper::ImportRun', through:  :scraper_page

  belongs_to :spree_product, -> { with_deleted }, foreign_key: 'spree_product_id', class_name:'Spree::Product'
  alias_method :product, :spree_product


  # belongs_to :scraper_import_run, foreign_key:'scraper_import_run_id', class_name:'Scraper::ImportRun'

  scope :not_reviewed, -> { joins(:spree_product).where("#{Spree::Product.quoted_table_name}.last_review_at IS NULL") }
  scope :reviewed, -> { joins(:spree_product).where("#{Spree::Product.quoted_table_name}.last_review_at IS NOT NULL") }

  after_create :set_scraper_import_run_id_via_page

  def self.default_per_page
    60
  end

  def set_scraper_import_run_id_via_page
    page = Scraper::Page.find_by id: scraper_page_id
    if page
      latest_import_run_id = page.import_runs.last.try(:id)
      self.scraper_import_run_id = latest_import_run_id if latest_import_run_id
      latest_import_run_id
    end
  end

end