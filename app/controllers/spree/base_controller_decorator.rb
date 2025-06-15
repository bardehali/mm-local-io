##
# Override methods in Spree::Core::ControllerHelpers::Common
module Spree::BaseControllerDecorator

  def self.prepended(base)
    base.helper Spree::FrontendNavigationHelper
    base.helper Spree::MoreBaseHelper
    base.include Spree::Core::ControllerHelpers::MoreCommon
  end

  def terms_of_use
    render template: 'home/_terms_of_use'
  end

  def privacy_policy
    render template: 'home/_privacy_policy'
  end

end




::Spree::BaseController.prepend(::Spree::BaseControllerDecorator) if ::Spree::BaseController.included_modules.exclude?(::Spree::BaseControllerDecorator)
