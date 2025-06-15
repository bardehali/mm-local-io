module Spree::Admin::Orders::CustomerDetailsControllerDecorator
  def self.prepended(base)
    base.include ControllerHelpers::SellerManager
  end
end

Spree::Admin::Orders::CustomerDetailsController.prepend(Spree::Admin::Orders::CustomerDetailsControllerDecorator) if Spree::Admin::Orders::CustomerDetailsController.included_modules.exclude?(Spree::Admin::Orders::CustomerDetailsControllerDecorator)