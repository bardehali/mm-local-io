module Spree::Admin::UserSessionsControllerDecorator
  def self.prepended(base)
    base.include Spree::Core::ControllerHelpers::MoreCommon
  end
end

# Skip that decorator crap.  Just class define.
class Spree::Admin::UserSessionsController
  include Spree::Core::ControllerHelpers::MoreCommon

  def new
    redirect_to login_path
  end
end