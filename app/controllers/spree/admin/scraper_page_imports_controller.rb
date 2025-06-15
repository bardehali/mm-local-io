class Spree::Admin::ScraperPageImportsController < Spree::Admin::RecordReviewsController

  before_action :set_common

  def products
    @scraper_page_imports = collection
    @total_count_of_reviewed = ::Spree::ScraperPageImport.reviewed.count
    @total_count_of_not_reviewed = ::Spree::ScraperPageImport.not_reviewed.count
  end

  def select
    product_ids = (params[:product_main_image] || {} )
    product_ids_to_activate = []
    product_ids_to_delete = []
    (params[:product_main_image] || {} ).each_pair do|product_id, main_image_id|
      if main_image_id.to_i > 0 && (main_image = Spree::Image.where(id: main_image_id).first )
        # instead of precise image.viewable_type
        other_images = Spree::Image.where(viewable_type: main_image.viewable_type, viewable_id: main_image.viewable_id).
          where('id != ?', main_image_id)
        ActiveRecord::Base.transaction do
          other_images.update_all('position=position+1')
          main_image.set_list_position(1)
        end
        product_ids_to_activate << product_id
      else
        product_ids_to_delete << product_id
      end
    end
    time_now = Time.now
    if product_ids_to_activate.present?
      records_query = ::Spree::Product.where(id: product_ids_to_activate)
      records_query.update_all(last_review_at: time_now, available_on: time_now, iqs:  params[:iqs] || ::Spree::Product::ADMIN_CREATED_IQS )
      ::Spree::Product.bulk_index(records_query.to_a) if ::Spree::Product.respond_to?(:bulk_index) # TODO: remove when searchable
    end
    ::Spree::Product.where(id: product_ids_to_delete).update_all(last_review_at: time_now, deleted_at: time_now) if product_ids_to_delete.present?
    respond_to do|format|
      format.html { redirect_to(admin_imported_products_path(limit: params[:limit], filter: params[:filter], t: time_now.to_i ) )}
    end
  end

  protected

  def set_common
    params.permit!
    @page_title = t('spree.admin.tools.imported_products_review')
  end

  def collection
    return @collection if @collection
    sort = params[:sort] || 'scraper_page_id asc'
    @collection = ::Spree::ScraperPageImport.
      # left_joins(:scraper_import_runs).
      joins(:scraper_page, :spree_product).
      order("scraper_import_run_id asc, #{sort}").
      page(params[:page]).per( params[:limit] || ::Spree::ScraperPageImport.default_per_page )
    if params[:filter] == 'reviewed'
      @collection = @collection.reviewed
    elsif params[:filter] != 'all'
      @collection = @collection.not_reviewed
    end

    logger.info "| #{@collection.to_sql}"

    @collection
  end
end