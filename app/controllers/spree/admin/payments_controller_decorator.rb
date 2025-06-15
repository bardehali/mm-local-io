module Spree::Admin::PaymentsControllerDecorator
  def self.prepended(base)
    base.skip_before_action :authorize_admin if base.method_defined?(:authorize_admin) # Some rake runs would fail to load controller class
  end

end

if defined?(Spree::Admin::PaymentsController)
  Spree::Admin::PaymentsController.prepend(Spree::Admin::PaymentsControllerDecorator) if Spree::Admin::PaymentsController.included_modules.exclude?(Spree::Admin::PaymentsControllerDecorator)
end