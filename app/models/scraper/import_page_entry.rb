class Scraper::ImportPageEntry < ApplicationRecord
  self.table_name = 'scraper_import_runs_pages'

  belongs_to :import_run, class_name:'Scraper::ImportRun', foreign_key:'scraper_import_run_id'
  belongs_to :page, class_name:'Scraper::Page', foreign_key:'scraper_page_id'

  delegate :page_url, :page_type, :url_path, :url_params, :page_number, :pagination_number, :referrer_page_id, :root_referrer_page_id, to: :page

  def self.add_if_needed(url, import_run_attributes = {})
    uri = URI(url)
    scraper_page = ::Scraper::Page.add_if_needed(uri)
    page_entry = ::Scraper::ImportPageEntry.joins(:import_run).where(scraper_import_runs:{ retail_site_id: scraper_page.id } ).last
    if page_entry.nil?
      import_run = ::Scraper::ImportRun.create(
        retail_site_id: scraper_page.retail_site_id, 
        initiator_user_id: import_run_attributes[:initiator_user_id], 
        name: import_run_attributes[:name].present? ? import_run_attributes[:name] : "#{scraper_page.retail_site.name} Import on #{Time.now.to_s(:long)}",
        initial_url: url, keywords: import_run_attributes[:keywords], status: 'NEW' 
      )
      page_entry = ::Scraper::ImportPageEntry.create(scraper_import_run_id: import_run.id, scraper_page_id: scraper_page.id )
    end
    page_entry
  end

  # alias_method just cannot work
  def import_page_id
    scraper_import_run_id
  end
end