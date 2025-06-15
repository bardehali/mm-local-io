module Spree::Admin::PaymentMethodsControllerDecorator

  def collection
    super.
      where( params[:available_to_users].nil? ? nil : { available_to_users: params[:available_to_users]} ).
      where( params[:active].nil? ? nil : { active: params[:active]} ).
      page(params[:page]).limit(50)
  end
end

Spree::Admin::PaymentMethodsController.prepend(Spree::Admin::PaymentMethodsControllerDecorator) if Spree::Admin::PaymentMethodsController.included_modules.exclude?(Spree::Admin::PaymentMethodsControllerDecorator)