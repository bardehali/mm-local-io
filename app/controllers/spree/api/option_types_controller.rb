class Spree::Api::OptionTypesController < Spree::Api::BaseController

  respond_to :json, :js

  def related
    params.permit!

    record_type = params[:record_type]
    record_type = 'Spree::' + record_type.classify unless record_type.index('::')
    ids = params[:record_id].to_s.split(',').collect(&:to_i)

    @option_types = ::Spree::RelatedOptionType.closest_option_types(record_type, ids )
    @size_option_type = @option_types.find(&:size?)
    if params[:other_option_value_ids].present?
      @other_option_values = Spree::OptionValue.where(id: params[:other_option_value_ids] ).all
    end
  
    logger.debug "| #{record_type}(#{ids}) related option_types: #{@option_types.collect(&:name)}"
    
    @resource = record_type.constantize.find(ids.first)
    @product = ::Spree::Product.find(params[:product_id].to_i ) if params[:product_id].to_i > 0
    @variant = ::Spree::Product.find(params[:variant_id].to_i ) if params[:variant_id].to_i > 0

    respond_to do|format|
      format.js
      format.json {
        render json: @option_types.collect{|ot| ot.as_json_with_option_values(current_spree_user) } }
    end
  rescue NameError, ::ActiveRecord::RecordNotFound => record_error
    respond_to do|format|
      format.js { render js: "alert('Problem finding the record.  #{record_error}');" }
      format.json { render json:{} }
    end
  end

  ##
  # Ajax rendering of option type selection list or tables
  def load
    @option_types = Spree::OptionType.where(id: params[:option_type_ids] || params[:option_type_id] || params[:id] ).all
    @product = Spree::Product.find(params[:product_id]) if params[:product_id].to_i > 0
    @product_options_map = @product.try(:options_map, spree_current_user.try(:id))
    logger.debug "| @product_options_map: #{@product_options_map}"
    
    @size_option_type = @option_types.find(&:size?)
    @color_option_type = @option_types.find(&:color?)
    logger.debug "| @size_option_type: #{@size_option_type}"
    logger.debug "| @color_option_type: #{@color_option_type}"
    
    if (other_ids = params[:selected_option_value_ids]).present?
      @other_option_values = Spree::OptionValue.includes(:option_type).where(id: other_ids).all
      @other_option_values.each do|ov|
        ov.selected = @product_options_map.try(:[], ov.id).to_a.find(&:present?)
      end
      logger.debug "| @other_option_values #{@other_option_values.collect(&:name)}"
    end
  end

  def spree_current_user
    @current_api_user
  end
  helper_method :spree_current_user
end