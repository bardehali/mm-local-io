module Spree::Admin::VariantsControllerDecorator

  def self.prepended(base)
    base.before_action :set_current_user_id
  end


  private

  def collection
    @deleted = params.key?(:deleted) && params[:deleted] == 'on' ? 'checked' : ''
    return @collection if @collection
    
    model_includes = [:product, :prices, :default_price, option_values: :option_type, user:{ store:[:store_payment_methods] }]
    @collection ||=
      if @deleted.blank?
        super.includes(*model_includes).where(converted_to_variant_adoption: false)
      else
        Variant.only_deleted.includes(*model_includes).where(product_id: parent.id, converted_to_variant_adoption: false)
      end

    @collection = @collection.where(user_id: spree_current_user) if spree_current_user && !spree_current_user.admin?
    @collection
  end

  def set_current_user_id
    logger.info "| object #{@object.sku_and_options_text}, new #{@new}" if @object
    if @object
      @object.user_id ||= spree_current_user.try(:id)
    end
    @new.user_id = spree_current_user.try(:id) if @new && @new.respond_to?(:user_id=)
  end
end

Spree::Admin::VariantsController.prepend(Spree::Admin::VariantsControllerDecorator) if Spree::Admin::VariantsController.included_modules.exclude?(Spree::Admin::VariantsControllerDecorator)