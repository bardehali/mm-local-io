##
# Minimized version, without scraper.
class Retail::Site < ::ApplicationRecord

  self.table_name = 'retail_sites'

  attr_accessor :forced_scheme, :locale_words_count, :retail_store

  validates_presence_of :name, :domain

  has_many :pages, class_name: 'Scraper::Page', foreign_key: 'retail_site_id'
  has_many :site_categories, class_name: 'Retail::SiteCategory', foreign_key: 'retail_site_id'

  before_save :set_defaults

  def scraper_class
    ::Scraper::Base.scraper_class(name, site_scraper == 'Scraper::Base' ? nil : site_scraper)
  end

  def scraper
    @scraper ||= scraper_class.new
  end

  alias_method :agent, :scraper

  def name_normalized
    name.to_s.gsub(/(\s+)/, '').downcase
  end

  def page_type_for(url)
    scraper_class.page_type_for(url)
  end

  def abs_url(url)
    full_url = url
    full_url.insert(0, 'http:') if full_url.start_with?('//')
    full_url.insert(0, (forced_scheme || 'http') + '://' + domain ) unless full_url =~ /^(ht|f)tps?:\/\//
    full_url
  end

  def headers
    {'X-Requested-With' => 'XMLHttpRequest'}
  end

  def to_s
    "#{name} (#{id})"
  end

  def fetch_root_site_category
    @root_site_category ||= site_categories.where(depth: 0).last
    @root_site_category ||= Retail::SiteCategory.create(site_name: site.name, name: "#{site.name} categories", retail_site_id: id)
    @root_site_category
  end

  DOMAIN_REGEXP = /((www|cdn)\.)?(\w+)(\.[a-z]{2,3})?(\.[a-z]{2,3})?\Z/i # $3 being site name

  ##
  # @url should be the full address including site domain; else, include domain in options like domain: 'ioffer.com'
  def self.find_matching_site(url, options = {})
    domain = options[:domain]
    unless domain.present?
      domain ||= URI::HTTP.domain_base(url, false)
    end
    name = DOMAIN_REGEXP.match(domain).try(:[], 3) || domain.gsub(/(\.[a-z]{2,3})\Z/, '')
    site = find_or_create_by(name: name) do|_site|
      _site.domain = domain
    end
    site
  end

  def self.find_site_by_name_or_id(name_or_id)
    if name_or_id.is_a?(Integer)
      self.find_by_id(name_or_id)
    else
      self.find_by_name(name_or_id)
    end
  end

  def self.find_or_create_by_name(name)
    find_or_create_by(name: name.strip) do|_site|
      _site.domain = _site.name.gsub(/(\s+)/, '') + '.com'
      _site.name = name.gsub(/(\s+)/, '').downcase
    end
  end

  private

  def set_defaults
    begin
      self.domain = URI::HTTP.domain_base(domain)
    rescue Exception => domain_e
      logger.warn 'Invalid domain: ' + domain_e.message
    end
  end

end