require 'csv'

class Scraper::Page < ApplicationRecord

  self.table_name = 'scraper_pages'

  # Full attributes:  page_type, retail_site_id, retail_store_id, title, page_url, url_path, url_params,
  # page_number, referrer_page_id, root_referrer_page_id, file_path

  validates_presence_of :retail_site_id, :page_url

  PAGE_TYPES = %w|landing store index detail|

  FILE_STATUSES = %w|NOT_FETCHED FETCHING FETCHED SAVED CANCELLED PAGE_NOT_FOUND|
  COMPLETED_FILE_STATUSES = %w|SAVED CANCELLED PAGE_NOT_FOUND|

  belongs_to :retail_site, class_name: 'Retail::Site'
  belongs_to :retail_store, class_name: 'Retail::Store', optional: true
  belongs_to :referrer_page, class_name: 'Scraper::Page', foreign_key: 'referrer_page_id', optional: true
  alias_method :parent_page, :referrer_page

  has_many :following_pages, class_name: 'Scraper::Page', foreign_key: 'referrer_page_id'

  has_many :import_page_entries, class_name:'Scraper::ImportPageEntry', foreign_key:'scraper_page_id', dependent: :destroy
  has_many :import_runs, class_name:'Scraper::ImportRun', through: :import_page_entries

  ##
  # Below is connection to Spree's side:
  # import_run 
  #   -=* import_page_entries 
  #       -=- page
  #           -=* scraper_page_imports
  #               -=- spree_product
  has_many :scraper_page_imports, class_name:'Spree::ScraperPageImport', foreign_key:'scraper_page_id', dependent: :delete_all
  has_many :spree_products, class_name:'Spree::Product', through: :scraper_page_imports
  alias_method :imported_spree_products, :spree_products

  delegate :scraper_class, :scraper, :abs_url, :to => :retail_site

  alias_attribute :pagination_number, :page_number

  attr_accessor :imported_spree_product_ids

  ##
  # Scopes
  scope :wait_for_fetch, -> { where("file_status IS NULL OR file_status='NOT_FETCHED'") }
  scope :fetched, -> { where("file_status='FETCHED'") }
  scope :not_saved, -> { where("file_status != 'SAVED'") }
  scope :not_failed, -> { where("file_status NOT IN ('CANCELLED PAGE_NOT_FOUND')") }
  scope :incomplete, -> { where('file_status NOT IN (?)', COMPLETED_FILE_STATUSES) }

  before_validation :auto_fill
  before_save :normalize
  before_destroy :delete_files

  def self.which_site(url, options = {})
    u = url.is_a?(URI::HTTP) ? url : URI(url)
    ::Retail::Site.find_matching_site(u.to_s )
  end

  ##
  # If @url does not contain the domain, provide inside options[:domain].
  # @url <URI::Generic or String of some URL>
  # @options <Hash> the attributes of record
  #   :retail_site <Retail::Site> optional; provide this to avoid having to query according to +url+
  def self.find_same_page(url, options = {})
    u = url.is_a?(URI::Generic) ? url : URI(url)
    site = options[:retail_site] || which_site(u, options)
    return nil if site.nil?
    where(retail_site_id: site.id, url_path: u.path, url_params: u.sorted_query(false) ).last
  end

  ##
  # If @uri does not contain the domain, provide inside options[:domain].
  # @uri <URI::Generic>
  # @options <Hash> the attributes for searching or creating the page
  # @return <Scraper::Page> could be nil if no matching site.
  def self.add_if_needed(uri, options = {})
    return nil if uri.nil?
    site = which_site(uri, options)
    return nil if site.nil? || uri.nil?

    p = find_same_page(site.scraper_class.clean_page_url(uri.to_s), retail_site_id: site.id)
    if p
      p.update_attributes(options) if options.size > 0
    else
      p = create_from_uri(uri, site, options )
    end
    p
  end

  # @uri <URI::Generic>
  def self.create_from_uri(uri, site = nil, options = {})
    site ||= ::Retail::Site.find_matching_site(uri.to_s)
    create( 
      options.select{|pname,pvalue| [:title, :referrer_page_id, :root_referrer_page_id, :retail_store_id, :page_type].include?(pname) }.merge(
        retail_site_id: site.id, page_url: site.scraper_class.clean_page_url(uri.to_s)
      )
    )
  end

  def self.base_dir
    root_path = Rails.root.to_s
    root_path.gsub!(/(\/releases\/\d+\/)/, '/current/')
    File.join( root_path, "public/spree/spages_#{Rails.env.downcase}/" )
  end

  ################################
  # Instance

  # @return [either Mechanize::Page or Nokogiri::HTML::Document]
  def fetch_if_needed
    if file_path.blank? || !File.exists?(file_path)
      fetch!
    else
      Nokogiri::HTML( File.open(file_path) )
    end
  end

  def fetch_ruby!
    scraper = ::Scraper::Base.scraper_class(retail_site.name).new
    scraper.user_agent = ::Scraper::Base::USER_AGENT_ALIASES_TO_USE.shuffle.first
    page = scraper.get abs_page_url
    if page.code[/30[12]/]
      self.update(page_url: scraper.current_page.uri.path , file_path: nil, file_status: 'NOT_FETCHED')
      page = agent.get page.header['location']
    end
    save_page(page)
  rescue Mechanize::ResponseCodeError => response_e
    logger.info "| Page (#{id}) fetch error #{response_e.message}, response_code #{response_e.response_code} [#{response_e.response_code.class}]"
    if response_e.response_code == '404'
      self.update(file_path: nil, file_status: 'PAGE_NOT_FOUND')
    elsif response_e.response_code == '302'
      self.update(page_url: scraper.current_page.uri.path , file_path: nil, file_status: 'NOT_FETCHED')
    end
  end

  ##
  # Using NodeJS scraper, if detail page, fetch page source and parse into product data.
  # Then create Spree::Product if needed.  If other pages, would fetch page URLs of other index and product pages.
  # @create_products [Boolean] default false; if detail whether always create new product; else passed onto fetch_other_pages!
  # @return [either Spree::Product for detail type or Collection of Scraper::Page for other page types]
  def fetch!(use_saved_file = true, create_products = false )
    self.create_import_run_if_needed!
    self.file_status = 'FETCHING'
    self.save
    return_vallue = nil
    `mkdir -p #{page_dir}`
    return_value = if page_type == 'detail'
      fetch_product!(create_products)
    else
      fetch_other_pages!(create_products) # would not return nil but empty Array
    end
    
  rescue JSON::ParserError => parser_e
    logger.info "** Problem parsing #{id}: #{parser_e}"
    logger.info "w/ return_value ------------------------\n#{return_value}"
  rescue Exception => fetch_e
    logger.info "** Problem fetching #{id}: #{fetch_e}: #{fetch_e.backtrace}"
    self.update(file_status: 'NOT_FETCHED')
  ensure
    if file_status == 'FETCHING'
      self.update(file_status: 'NOT_FETCHED')
    end
    return_value
  end

  ##
  # If saved file exists
  def product_attributes
    h = retail_site.scraper.find_product_attributes(make_mechanize_page)
    h
  rescue IOError => io
    h ||= {}
    h['error'] = io.message
    h
  end

  ##
  # Based on @product_attributes result
  def make_product
    a = product_attributes
    product = Spree::Product.new(a.select{|k,v| [:name, :price, :description].include?(k) } )
    product
  end

  def make_product_from_page(mechanize_page)
    retail_site.scraper.make_product(mechanize_page)
  end

  ##
  # Using NodeJS scrape_product.js script.
  def fetch_product!(create_products = false, output = nil)
    product = nil
    file_path = make_file_path
    logger.debug "#{id} ----------> go fetch #{page_url}"        
    output ||= `node script/nodejs/pupscraper/scrape_product.js "#{page_url}" "#{file_path}"`
    if output.present?
      logger.debug "output size: #{output.size}"
      product_h = JSON.parse(output)
      if product_h['error'].try(:[], 'name') =~ /unavailable/i
        self.update(file_status: 'CANCELLED')
      else
        product_h['scraper_page_id'] = self.id
        product_h['name'] ||= product_h['title']
        product = !create_products ? spree_products.first : nil
        if product
          logger.debug "  use existing product #{product.id}"
          product.attributes = product_h.slice('name', 'description', 'meta_description', 'meta_keywords')
          product.price = product_h['price'].to_f if product_h['price'].to_f > 0.0
          if product.user_id.nil?
            store_user = ::Spree::Product.find_or_create_store_and_user(product_h, retail_site_id)
            product.user_id ||= store_user.id if store_user
          end
          product.save
          product.set_category_taxon(product_h)
          self.update(file_status: 'SAVED', file_path: file_path )
        else
          product = ::Spree::Product.create_from_hash(product_h, retail_site)
          if product_h && product_h['error'] =~ /not\s+found/i
            self.update(file_status: 'CANCELLED')
          else
            self.update(file_status: 'SAVED', file_path: file_path )
          end
        end
      end # if error
    end
    product
  end

  MAX_COUNT_OF_INDEX_PAGES = 3

  ##
  # @create_products [Boolean] whether to use found productPages and fetch & create 
  #   products.
  # @return [Collection of Scraper::Page]
  def fetch_other_pages!(create_products = false, output = nil)
    entries = []
    page_url_to_scraper_page_id_map = {}

    output ||= `node script/nodejs/pupscraper/scrape_pages.js "#{self.retail_site.abs_url(page_url)}" "#{self.make_file_path}"`
    json = JSON.parse(output)
    json.each_pair do|list_key, list_value|
      logger.debug "| Found #{list_key}: #{list_value.size}"
    end
    import_run_id = self.import_page_entries.first.try(:scraper_import_run_id)
    base_page_attr = { referrer_page_id: id, root_referrer_page_id: root_referrer_page_id || self.id }

    index_pages = json['indexPages'].to_a
    index_pages = index_pages[0, MAX_COUNT_OF_INDEX_PAGES] unless retail_site.page_type_for(page_url) == 'store'
    index_pages.each do|index_url|
      uri = URI(index_url)
      next unless uri.is_a?(URI::HTTP) || retail_site.page_type_for(index_url) != 'index'
      scraper_page = ::Scraper::Page.add_if_needed( uri, base_page_attr.merge(page_type:'index') )
      page_entry = ::Scraper::ImportPageEntry.find_or_create_by(scraper_import_run_id: import_run_id, scraper_page_id: scraper_page.id) if import_run_id
      entries << scraper_page
    end
    json['productPages'].to_a.each do|product_url|
      begin
        uri = URI(product_url)
        next unless uri.is_a?(URI::HTTP)
        scraper_page = ::Scraper::Page.add_if_needed( uri, base_page_attr.merge(page_type:'detail') )
        page_entry = ::Scraper::ImportPageEntry.find_or_create_by(scraper_import_run_id: import_run_id, scraper_page_id: scraper_page.id)
        entries << scraper_page
        page_url_to_scraper_page_id_map[product_url] = scraper_page.id
      rescue Exception => url_e
      end
    end

    if create_products
      json['products'].to_a.each do|product_h|
        next unless %w(title description photos).all?{|attr| product_h.keys.include?(attr) }
        if product_h['page_url'].present?
          scrape_page_id = page_url_to_scraper_page_id_map[product_h['page_url'] ]
          product_h['scraper_page_id'] = scrape_page_id if scrape_page_id
        end
        
        ::Spree::Product.create_from_hash(product_h, retail_site)
      end
    end
    entries
  end

  ##
  # Possible no ImportRun at all for this site.
  def create_import_run_if_needed!
    if import_runs.count == 0
      import_run = Scraper::ImportRun.create(
        retail_site_id: retail_site_id, initial_url: abs_page_url, 
        initiator_user_id: ::Spree::User.fetch_admin.id )
      import_run.import_page_entries.create(scraper_page_id: id)
    else
      import_run = import_runs.last
      import_run.import_page_entries.find_or_create_by(scraper_page_id: id)
    end
    import_run
  end

  ## 
  # Deletes existing file, and file_status
  def reset!
    if file_path.present? && File.exists?(file_path)
      FileUtils.remove(file_path)
    end
    self.update(file_status: 'NOT_FETCHED', file_path: nil)
  end

  #####################################
  # Attributes

  def succeeded?
    file_status == 'SAVED'
  end

  def completed?
    COMPLETED_FILE_STATUSES.include?(file_status&.upcase)
  end

  def abs_page_url
    retail_site.abs_url(page_url)
  end
  alias_method :absolute_page_url, :abs_page_url

  def relative_page_url
    URI(retail_site.abs_url(page_url) ).request_uri
  end

  def relative_file_url
    file_path ? file_path[ file_path.index('/spages_'), file_path.size ] : ''
  end

  def fix_pagination_number!
    self.page_number = self.retail_site.scraper.class.find_pagination_number(page_url.uri)
    self.save
    self.page_number
  rescue URI::InvalidURIError
    logger.warn "Invalid URI on #{self}"
  end

  ##
  # For PageRequest to be used to calculate the priority of requests to run on the queue.
  def priority_factor
    case page_type
      when 'detail'
        10
      when 'index'
        page_number.to_i <= 10 ? 5 : 3
      else
        2
    end
  end



  ########################################
  # Local file methods

  ##
  # Making of the path with folders that separate pages into grouped folders.
  def page_subfolder
    subfolder_path = ''
    id_s = id.to_s(16)
    0.upto(id_s.size - 1) do|i|
      subfolder_path << '/' if i > 0 && i % 3 == 0
      subfolder_path << id_s[i]
    end
    subfolder_path
  end

  def page_dir
    File.join(self.class.base_dir, page_subfolder )
  end

  def make_file_path(locale = nil)
    actual_file_path = File.join(page_dir, id.to_s + '.html')
    actual_file_path.gsub!(/(\.html)$/, ".#{locale}.html") if locale && locale != 'en-US'
    actual_file_path
  end

  def page_file_relative_url
    file_path.present? ? file_path[ file_path.index('/spages_'), file_path.size ] : nil
  end

  ##
  # Save this to local.
  # @page_object <Mechanize::Page>
  def save_page(page_object, locale = nil, do_update_attributes = true)
    file_path = make_file_path
    actual_file_path = make_file_path(locale)
    `mkdir -p #{page_dir}`
    BG_LOGGER.debug "> saving #{page_url} to #{actual_file_path}"
    begin
      File.open( actual_file_path, "w:#{Encoding::ASCII_8BIT}" ) do|f|
        f.write(page_object.body.encode(Encoding::ASCII_8BIT) )
      end
      self.update_attributes(file_path: file_path, file_status: 'FETCHED' ) if do_update_attributes
    rescue IOError
      self.update_attributes(file_path: nil, file_status: 'NOT_FETCHED' ) if do_update_attributes
    end
    actual_file_path
  end

  # For recreating the page object after save.
  # @return <Mechanize::Page> might be nil if cannot read from file_path
  def make_mechanize_page(agent = nil, locale = nil)
    return nil if file_path.blank? || !File.exists?(file_path)
    agent ||= retail_site.scraper
    actual_file_path = (locale.blank? || locale == 'en-US') ? file_path :
      file_path.gsub(/(\.html)$/, ".#{locale}.html")
    File.open(actual_file_path, 'r:UTF-8') do|f|
      ::Mechanize::Page.new( URI( retail_site.abs_url(page_url)), nil, f.read, 200, agent )
    end
  rescue Errno::ENOENT
    nil
  end

  PAGE_FILENAME_REGEX = /(\.[\w]{2,3}\-[\w]{2,3})?\.html$/

  ##
  # @return <Hash locale => URL path>
  def file_versions
    h = {}
    return h unless Dir.exist?(page_dir)
    url_prefix = "/spages_#{Rails.env.downcase}/#{page_subfolder}"
    Dir.entries( page_dir ).each do|fname|
      if match = PAGE_FILENAME_REGEX.match(fname)
        if match[1]
          h[ match[1][1, match[1].size ] ] = url_prefix + '/' + fname
        else
          h['en-US'] = url_prefix + '/' + fname
        end
      end
    end
    h
  end

  ##
  # If has file_path of saved page, would delete all files of page folder.
  def delete_files
    if file_path.present?
      FileUtils.rm_r(page_dir, force: true)
      self.update_attributes(file_path: nil)
    end
  end


  #############################
  # Data exports

  # @return <Array>
  def to_csv_row_values
    self.class.csv_columns.collect do |c|
      self.send(c.to_sym)
    end
  end


  def self.csv_columns
    %w|relative_page_url page_type|
  end

  # @return <CSV::Row>
  def self.csv_header
    cols = csv_columns
    CSV::Row.new(cols.collect(&:to_sym), cols, true)
  end

  protected

  def auto_fill
    if retail_site_id.to_i == 0
      self.retail_site = ::Retail::Site.find_matching_site(page_url)
    end
  end

  MAX_PAGE_URL_LENGTH = 360

  # Sets page_type,
  def normalize
    uri = page_url.index('ruby/object') ? YAML::load(page_url) : URI(page_url)
    self.page_url = scraper_class.clean_page_url( uri.to_s )
    self.page_url = 'http:' + page_url if uri.scheme.nil? && page_url.starts_with?('//')
    uri = URI(page_url)
    self.url_path = uri.path
    self.url_params = uri.sorted_query(false)

    self.page_type = scraper_class.page_type_for(page_url) if page_type.blank?
    self.title = title.squish if title
    self.file_status = 'NOT_FETCHED' if file_status.blank?
  end

end
