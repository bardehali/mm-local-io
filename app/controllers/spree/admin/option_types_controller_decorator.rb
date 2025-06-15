module Spree::Admin::OptionTypesControllerDecorator

  def self.prepended(base)
    base.before_action :load_option_values, only: [:edit]
  end

  ##
  # Paginate @option_type.option_values to @option_values
  def load_option_values
    @option_type ||= resource
    page_no = [params[:page].to_i, 1].max
    limit = params[:limit] || 100
    # instead of @option_type.option_values, this allows pagination
    @option_values ||= Spree::OptionValue.where(option_type_id: @option_type.id).order('position ASC').page(params[:page] ).per(params[:limit])
    # ((page_no - 1) * limit ).limit(limit)
  end
end

Spree::Admin::OptionTypesController.prepend(Spree::Admin::OptionTypesControllerDecorator) if Spree::Admin::OptionTypesController.included_modules.exclude?(Spree::Admin::OptionTypesControllerDecorator)