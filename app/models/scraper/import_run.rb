class Scraper::ImportRun < ApplicationRecord
  require 'open-uri'

  self.table_name = 'scraper_import_runs'

  validates_presence_of :initial_url, :retail_site_id

  belongs_to :retail_site, class_name:'Retail::Site'
  belongs_to :initiator, class_name:'::Spree::User', foreign_key:'initiator_user_id'

  has_many :import_page_entries, class_name:'Scraper::ImportPageEntry', foreign_key:'scraper_import_run_id', dependent: :destroy
  alias_method :page_entries, :import_page_entries
  has_many :pages, class_name:'Scraper::Page', through: :import_page_entries

  before_validation :normalize_attributes

  SEARCH_KEYWORD_PARAMETER_REGEXP = /\Asearchtext|q|query|term|keywords?\Z/i

  ##
  # Fetch using the script.
  # @return <Array of Scraper::ImportPageEntry>
  def fetch!
    initial_page_uri = URI(retail_site.abs_url(initial_url)) 
    initial_page = ::Scraper::Page.add_if_needed( initial_page_uri )
    initial_page.fetch!(true)

  rescue Exception => parse_e
    logger.warn "** Problem fetching ImportRun(#{id}): #{parse_e.message}\n#{parse_e.backtrace}"
    []
  end

  # handle_asynchronously :fetch!, queue: 'scraper_run' # TODO: restore

  def reset!(delete_pages = false)
    if delete_pages
      self.import_page_entries.each{|entry| entry.page.destroy }
    end
    self.import_page_entries.delete_all
  end

  protected

  def normalize_attributes
    uri = URI(initial_url)
    if retail_site_id.nil? && retail_site.nil?
      site_name = URI::HTTP.domain_base(initial_url)
      self.retail_site_id = Retail::Site.find_or_create_by(domain: site_name) do|site|
        site.name = uri.host_parts[:sld]
        begin
          site_scraper = 'Scraper::' + uri.host_parts[:sld].titleize
          site_scraper.constantize
          site.site_scraper = site_scraper
        rescue NameError
        end
      end.try(:id)
    end
    if keywords.blank?
      params_list = uri.query.to_s.split('&').collect{|pair| pair.split('=') }
      found_value = params_list.find{|pair| pair[0] =~ SEARCH_KEYWORD_PARAMETER_REGEXP }.try(:[], 1)
      self.keywords = found_value if found_value.present?
    end
  end

end