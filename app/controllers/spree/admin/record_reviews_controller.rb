class Spree::Admin::RecordReviewsController < Spree::Admin::BaseController

  inherit_resources 

  before_action :authorize_admin
  before_action :set_version
  
  # layout 'spree/layouts/admin_minimized'

  helper ::Spree::ProductsHelper

  def products
    params.permit!
    @page_title = I18n.t('spree.admin.tools.curation_by_image')
    
    @total_count_of_not_reviewed = ::Spree::Product.not_reviewed.count
    @total_count_of_reviewed = ::Spree::Product.reviewed.count

    load_products

    logger.debug "| params: #{request.path}"
  end

  ##
  # Expected params:
  #   record_type"=>"Spree::Product", "status_code"=>"", "status_code_6"=>"100", "status_code_7"=>"100",
  #     where status_code_ddd => 100 represents the status_code that this record (id = ddd) would be updated to.
  def mark_reviewed
    params.permit!
    status_code_to_record_ids = {}
    only_reviewed_record_ids = []
    biggest_record_id = 0
    params.each_pair do|k, v|
      next unless k =~ /\Astatus_code_(\d+)\Z/
      biggest_record_id = [biggest_record_id, $1.to_i].max
      if v.to_i > 0
        list = status_code_to_record_ids[v] || []
        list << $1
        status_code_to_record_ids[v] = list
      elsif v == ''
        only_reviewed_record_ids << $1
      end
    end

    if only_reviewed_record_ids.size > 0
      logger.info "| only_reviewed_record_ids #{only_reviewed_record_ids}"
      records = params[:record_type].constantize.where(id: only_reviewed_record_ids)
      records.update(last_review_at: Time.now)
    end

    logger.info "| status_code_to_record_ids: #{status_code_to_record_ids}"
    status_code_to_record_ids.each_pair do|status_code, record_ids|
      if status_code.to_s == ''
        params[:record_type].constantize.where(id: record_ids ).update(last_review_at: Time.now)
      else
        record_ids.each do|record_id|
          record_review = ::Spree::RecordReview.find_or_create_by(record_type: params[:record_type], record_id: record_id ) do|record|
            record.status_code = status_code
          end
          record_review.update(status_code: status_code )
        end
      end
    end

    respond_to do|format|
      format.html { redirect_to(admin_niir_version_path(version: params[:version], t: Time.now.to_i ) )}
    end
  end

  def create
    h = permit_params
    if h[:status_name].present? && params[:status_code].nil?
      h[:status_code] = ::Spree::RecordReview::NAME_TO_STATUS_CODE_MAPPING[ h[:status_name].titleize ]
    end
    is_new_record = false
    @record_review = ::Spree::RecordReview.find_or_create_by(h.slice(:record_type, :record_id)) do|record|
      record.status_code = h[:status_code]
      is_new_record = true
    end
    @record_review.new_curation_score = h[:new_curation_score]
    logger.info " -> new_curation_score: #{@record_review.new_curation_score}"

    @record_review.update(status_code: h[:status_code] ) unless is_new_record

    @next_product = load_products.last
    logger.info " .. next product #{@next_product&.slug}"

    respond_to do|format|
      format.js
      format.json { render json: @record_review }
    end
  end

  protected

  def permit_params
    params.require(:record_review).permit(:record_type, :record_id, :status_code, :status_name, :new_curation_score)
  end

  def set_version
    params[:version] ||= 'old' if request.path.index('niir/old')
  end

  def collection
    end_of_chain = end_of_association_chain
    if params[:last_product_id].to_i > 0
      end_of_chain = end_of_chain.where("`#{Spree::Product.table_name}`.`id` > ?", params[:last_product_id] )
    else
      end_of_chain = end_of_chain.page(params[:page])
    end
    get_collection_ivar || set_collection_ivar( end_of_chain.joins(:product) )
  end

  def load_products
    order = params[:order]

    @products = ::Spree::Product.includes(:variant_images, 
      user:[:ioffer_user, :user_stats, store:[:store_payment_methods] ]).left_joins(:record_review)
    @products = order.present? ? @products.order(order) : @products.order_for_review
    if %w(all).include?(params[:filter] )
    elsif params[:filter] == 'reviewed'
      @products = @products.reviewed # .order("#{Spree::RecordReview.table_name}.iqs desc")
    else
      @products = @products.not_reviewed # .with_acceptable_status
    end
    @products = @products.with_deleted if params[:include_deleted]

    if params[:last_product_id].to_i > 0
      @products = @products.where("`#{Spree::Product.table_name}`.`id` > ?", params[:last_product_id] ).page(1).per(params[:limit] || ::Spree::RecordReview.default_per_page)
    else
      @products = @products.page(params[:page] ).per(params[:limit] || ::Spree::RecordReview.default_per_page)
    end
    logger.debug "| q: #{@products.to_sql}"
    @products
  end
end