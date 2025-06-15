class Retail::SiteCategoriesController < Spree::Admin::BaseController

  layout 'spree/layouts/admin'
  
  inherit_resources

  include Spree::Core::Engine.routes.url_helpers
  helper Spree::Core::Engine.routes.url_helpers
  helper Rails.application.routes.url_helpers

  before_action :set_common
  before_action :update_recent_categories, only: [:update, :show, :index]

  def index
    logger.info "| SiteCategory params #{params}"

    @site_names = Retail::SiteCategory.select('site_name').distinct.collect(&:site_name)

    respond_to do|format|
      format.html
    end
  end

  def show
    super do|format|
      format.js
    end
  end

  def update
    super do|format|
      format.js
    end
  end

  def site_category_params
    params.require(:site_category).permit(:site_name, :name, :other_site_category_id, :parent_id, :mapped_taxon_id, :position, :depth)
  end

  private

  def set_common
    params.permit!

    @title = [@title, 'Site Categories'].compact.join(': ')
  end

  def update_recent_categories

    @recent_category_taxon_ids = session[:recent_category_taxon_ids] || []
    taxon_id = params[:site_category].try(:[], :mapped_taxon_id)
    if taxon_id
      @recent_category_taxon_ids.insert(0, taxon_id.to_i)
      @recent_category_taxon_ids.uniq!
      @recent_category_taxon_ids.slice!(10, @recent_category_taxon_ids.size - 10)
      session[:recent_category_taxon_ids] = @recent_category_taxon_ids
    end
    logger.debug "| after adding #{taxon_id}, recent: #{@recent_category_taxon_ids}"
  end

  def collection
    return @collection if @collection
    site_categories = []
    if params[:site_name].present?
      site_categories = Retail::SiteCategory.where(depth: 1).order('position asc')
      if params[:site_name] == 'all'
        site_categories = site_categories.order('site_name')
      else
        site_categories = site_categories.where(site_name: params[:site_name] )
      end
    else
      site_categories = []
    end
    @collection = site_categories
    @collection
  end
end