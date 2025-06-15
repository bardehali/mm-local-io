module Spree::Admin::BaseControllerDecorator
  def self.prepended(base)

  end
end

class Spree::Admin::BaseController
  helper ::Spree::Admin::MoreNavigationHelper
  helper ::Admin::StatsHelper

  before_action :authorize_seller!, except: [:home]
  before_action :authorize_real_admin, only: [:dashboard, :stats]

  if respond_to?(:authorize_admin)
    skip_before_action :authorize_admin, only: [:home]
  end

  def current_store
    @current_store = Rails.cache.fetch('current_store'){ Spree::Store.first }
  end

  def home
    logger.debug "| user #{spree_current_user}, buyer? #{spree_current_user&.buyer?}, seller? #{spree_current_user&.seller?}"
    redirect_to after_sign_in_path_for(spree_current_user)
  end

  SQL_DAY_FORMAT = '%Y-%m-%d' unless defined?(SQL_DAY_FORMAT)
  SQL_DATE_AND_HOUR_FORMAT = '%Y-%m-%d %H' unless defined?(SQL_DATE_AND_HOUR_FORMAT)

  def dashboard
    @title = 'Dashboard'

    render params[:v] == 'charts' ? 'spree/admin/dashboard_charts' : 'spree/admin/dashboard'
  end

  def stats
    @title = 'Stats'
    render layout: 'spree/layouts/only_main_content', template: 'spree/admin/stats'
  end

  def authorize_real_admin
    authorize! :admin, User::Stat
  end
end

# ::Spree::Admin::BaseController.prepend Spree::Admin::BaseControllerDecorator if ::Spree::Admin::BaseController.included_modules.exclude?(Spree::Admin::BaseControllerDecorator)
