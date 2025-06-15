##
# Full replacement of short original file.
module Spree::Core::ControllerHelpers::MoreStore
  extend ActiveSupport::Concern

  def current_currency
    if defined?(session) && session.key?(:currency) && supported_currencies.map(&:iso_code).include?(session[:currency])
      session[:currency]
    elsif params[:currency].present? && supported_currencies.map(&:iso_code).include?(params[:currency])
      params[:currency]
    else
      current_store.try(:default_currency) || Spree::Store.admin_store.default_currency
    end
  end

  ##
  # Page specific store: for example, product or variant to be seller's store.
  def current_store
    # logger.debug "| current_store w/ @object #{@object}, @variant #{@variant.try(:attributes)}, @order #{@order}"
    @current_store ||= 
      if @object.is_a?(Spree::VariantAdoption) || @object.is_a?(Spree::Variant) || @object.is_a?(Spree::Product)
        @object.user.try(:fetch_store) || Spree::Store.admin_store
      elsif @order.is_a?(Spree::Order)
        @order.store || @order.seller&.fetch_store || Spree::Store.admin_store
      elsif @variant.is_a?(Spree::Variant)
        @variant.user.try(:fetch_store) || @variant.product.user.try(:fetch_store) || Spree::Store.admin_store
      elsif @object.is_a?(::Spree::Store)
        @object
      elsif @store.is_a?(::Spree::Store)
        @store
      else
        Spree::Store.includes(:user).where(code: 'ioffer-store').first || Spree::Store.current('ioffer.com')
      end
  end


  private

  def current_tax_zone
    @current_tax_zone ||= @current_order&.tax_zone || Spree::Zone.default_tax
  end

end