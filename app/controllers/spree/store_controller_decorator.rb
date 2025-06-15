module Spree::StoreControllerDecorator
  def self.prepended(base)
    base.include Spree::Core::ControllerHelpers::MoreStore
    base.include Spree::Core::ControllerHelpers::MoreOrder
    base.include Spree::Admin::Shared::AdoptionHelper

    base.helper Spree::MoreUsersHelper
  end

  def cart_link
    find_all_orders_by_token_or_user(:line_items)
    @count_of_line_items = @orders.collect{|order| order.line_items.collect(&:variant_id) }.flatten.uniq.size

    render partial: 'spree/shared/link_to_cart'
    fresh_when(@orders)
  end

  protected

  ##
  # Determines whether to go to iOffer signup landing page or actuall spree homepage for buyer.
  def render_homepage
    if spree_current_user.try(:admin?) || source_country?(spree_current_user&.country)
      logger.debug " -> #{spree_current_user}, going to wanted_products or source_homepage?"
      if spree_current_user
        redirect_to spree_current_user.admin? ? '/admin' : admin_wanted_products_path
      else
        params[:state] = 'complete'
        load_orders_with_state
        @top_products = cache_of_mostly_viewed_products

        render template: 'home/source_country_homepage', layout:'spree/layouts/spree_application'
      end
    elsif accepted_location_for_buyer?
      render template: 'home/spree_home', layout:'spree/layouts/spree_application'

    else
      render template: 'home/index', layout:'ioffer_application'
    end
  end

  ##
  # Originally from api/app/controllers/spree/api/v2/base_controller.rb.
  # First check to use try_current_user.  Otherwise, load user
  # with added includes roles for Geofence to check
  def spree_current_user
    @spree_current_user ||= try_spree_current_user if respond_to?(:try_spree_current_user)
    return @spree_current_user if @spree_current_user

    return nil unless doorkeeper_token
    doorkeeper_authorize!

    @spree_current_user ||= Spree.user_class.includes(:spree_roles).find_by(id: doorkeeper_token.resource_owner_id)
  end

end

Spree::StoreController.prepend(Spree::StoreControllerDecorator) if Spree::StoreController.included_modules.exclude?(Spree::StoreControllerDecorator)
