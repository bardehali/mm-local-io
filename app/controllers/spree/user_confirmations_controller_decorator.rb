module Spree::UserConfirmationsControllerDecorator
  def self.prepended(base)
    base.include Spree::Core::ControllerHelpers::MoreCommon
  end
end

Spree::UserConfirmationsController.prepend(Spree::UserConfirmationsControllerDecorator) if Spree::UserConfirmationsController.included_modules.exclude?(Spree::UserConfirmationsControllerDecorator)