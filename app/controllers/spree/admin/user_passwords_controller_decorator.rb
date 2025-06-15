module Spree::Admin::UserPasswordsControllerDecorator
  def self.prepended(base)
    base.include Spree::Core::ControllerHelpers::MoreCommon
  end
end

Spree::Admin::UserPasswordsController.prepend(Spree::Admin::UserPasswordsControllerDecorator) if Spree::Admin::UserPasswordsController.included_modules.exclude?(Spree::Admin::UserPasswordsControllerDecorator)