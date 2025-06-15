class Scraper::PagesController < ApplicationController

  inherit_resources

  layout 'spree/layouts/admin'

  helper ::Retail::SitesHelper

  before_action :populate_search, only: [:index]
  before_action :authorize_admin, only: [:create]

  def show
    @page_title = "Page (#{params[:id]})"
    super
  end

  def show_product_from_saved_page
    @product = resource.retail_product
    unless @product
      agent = resource.retail_site.scraper
      mechanize_page = resource.make_mechanize_page(agent, params[:locale])
      @product = resource.make_product_from_page(mechanize_page, false)
    end
    logger.info "product: #{@product}"
    respond_to do|format|
      format.js
    end
  end

  ##
  # Fetch page
  def update
    params.permit(:scraper_page, :reparse, :update_product_card, :scraper_page_ids)
    logger.info "| update page #{resource.id}, reparse? #{params[:reparse]}"
    if params[:reparse]
      resource.fetch!
    else
      resource.fetch_if_needed
    end
  rescue Exception => e
    logger.warn e.message
    logger.warn e.backtrace.join("\n  ")
    @exception = e
  ensure
    respond_to do|format|
      format.js
    end
  end

  ##
  # Simply calls Scraper::Page#fetch!, either creating product or adding more pages.
  # Different from #update which saves source in file first and uses Ruby-based 
  # scraper to parse the page source.
  def fetch
    result = resource.fetch!
    logger.info "** result: #{result}"
    if resource.page_type == 'detail'
      @spree_product = result
      if @spree_product
        import_run = resource.create_import_run_if_needed!
        import = ::Spree::ScraperPageImport.find_or_initialize_by(scraper_page_id: resource.id, spree_product_id: @spree_product.id)
        import.scraper_import_run_id ||= import_run.id
        import.save
      end
    else
      @scraper_pages = result
    end
  rescue Exception => action_e
    logger.warn "** Error fetching page(#{resource.try(:id)}: #{action_e}\n#{action_e.backtrace}"
    @error = action_e
  end

  def source_file
    @source = ''
    if resource.file_path.blank?
      @source = '<h3> No file saved for this page</h3>'
    elsif !File.exists?(resource.file_path)
      @source = "<h3>File not found #{resource.file_path}</h3>"
    else
      @source = File.open(resource.file_path).read
    end
  end

  def destroy
    last_run = resource.import_runs.try(:last)
    super do|format|
      format.html { redirect_to scraper_pages_path }
      format.js
    end
  end

  def preview
    params.permit(:source, :name, :retail_site_id)
    @page = Scraper::Page.new(retail_site_id: params[:retail_site_id], page_type:'detail')
    if params[:source].present?
      @source = params[:source]
      @retail_site = if params[:retail_site_id].to_i > 0
          Retail::Site.find_by_id(params[:retail_site_id])
        else
          Retail::Site.where(name: params[:name] || 'ioffer').first
        end
      @page.retail_site = @retail_site  
      if @retail_site  
        @mechanize_page = Mechanize::Page.new( URI('/admin/pages/source'), nil, params[:source], 200, @retail_site.scraper)
        @product = @page.make_product_from_page(@mechanize_page)
      end
    end
  end

  protected

  def populate_search
    params[:q] ||= {}
    [:retail_site_id, :url_path].each do|pname|
      params[:q]["#{pname}_eq".to_sym] = params[pname] if params[pname]
    end
    if params[:url].present?
      @uri = URI( params[:url] )
      @retail_site = params[:q][:retail_site_id_eq] ?
        ::Retail::Site.find(params[:q][:retail_site_id_eq]) : ::Retail::Site.find_matching_site(params[:url] )
    end
    unless @pages && @search
      @search = ::Scraper::Page.ransack(params[:q])
      @pages = @search.result.includes(:retail_site, :scraper_page_imports).page(params[:page] ).per(50).order('id desc')
      if params[:url].present?
        @uri = URI( params[:url] )
        @retail_site = params[:retail_site_id] ?
          ::Retail::Site.find(params[:retail_site_id]) : ::Retail::Site.find_matching_site(params[:url] )
        @pages = @pages.where(retail_site_id: @retail_site.id) if @retail_site
        @pages = @pages.where(url_path: @uri.path )
      end
    end
    if @pages.count == 1
      return redirect_to( scraper_page_path(@pages.first) )
    else
      logger.info "| no of pages #{@pages.count}"
    end

    if params[:scraper_page]
      [:page_type].each do|a|
        @pages = @pages.where(a => params[:scraper_page][a] )
      end
    end
  end

  def collection
    super.includes(:retail_site, :scraper_page_imports)
  end

  private

  def page_params
    params.permit(:scraper_page, :reparse, :update_product_card)
    params.require(:scraper_page).permit(:page_type, :retail_site_id, :retail_store_id, :title, :page_url, :page_number,
                                 :referrer_page_id, :root_referrer_page_id, :file_path, :file_status)
  end

end
