##
# Because this class is based on parent class ActionController::API, much of the
# session and user features are not included.
module Spree::Api::V2::Storefront::CartControllerDecorator

  def self.prepended(base)
    base.helper ::ControllerHelpers::DebugHelper
    base.include ActionController::MimeResponds
    base.include Spree::Core::ControllerHelpers::MoreStore
    base.include Spree::Core::ControllerHelpers::MoreOrder
    base.skip_before_action :ensure_order, only: [:add_item, :select_variant] # load variant first
    base.before_action :load_variant, only: [:add_item, :select_variant]

    base.helper ApplicationHelper # Api controller rediculous not having this
    base.helper Spree::FrontendHelper
    base.helper Spree::MoreProductsHelper
    base.helper UsersHelper
    base.helper Spree::Admin::MoreUsersHelper
  end

  module UsersHelper
    ##
    # Assumes controller level would set the instance variable ahead.
    def spree_current_user
      @buyer
    end
  end

  def select_variant
    spree_authorize! :create, Spree::Order
    session['spree_user_return_to'] = request.referer if spree_current_user.nil?
    respond_to do|format|
      format.js
    end
  end

  ##
  # Copied over from original; changed to provide rendering also JS
  def add_item
    params.permit(:variant_id, :quantity, :payment_method_id)

    order = ensure_order(store_id: current_store.id,
      seller_user_id: @variant_adoption&.user_id || @variant.user_id)

    logger.debug "| vs order #{order.to_s}"
    logger.debug "| order_token #{order_token}, in format #{request.format}"

    spree_authorize! :update, order, order_token if spree_current_order && order
    spree_authorize! :show, @variant

    service = add_item_service

    quantity_to_add = params[:quantity]
    deleted_variant_ids = service.clean_line_items_similar_to(buyer&.id, order.token, @variant) do|line_item|
      if line_item.variant_id == @variant.id
        if params[:payment_method_id].to_i > 0
          quantity_to_add = 0
        end
      end
    end

    logger.debug "| deleted? #{deleted_variant_ids}, quantity_to_add #{quantity_to_add}"

    result = service.call(
      order: order,
      variant: @variant,
      quantity: quantity_to_add,
      options: (params[:options] || {} ).merge(variant_adoption_id: @variant_adoption&.id)
    )
    if result && result.value.is_a?(::Spree::LineItem)
      result.value.update_columns(referer_url: [params[:referer_url], session[::ControllerHelpers::ProductBrowser::LAST_VIEW_PRODUCT_REFERER] ].find(&:present?) )
      #add current user IP to the line item object created.
      result.value.set_user_ip(request.remote_ip)
      #add display prices to line_item

      # sets line_items display prices unless best price for item is nil.
      # this needs work as va price is likely incorrect.
      best_price = @variant&.product.best_price_record&.price
      if(best_price)
         va_price = @variant&.preferred_variant_adoption&.price ? @variant&.preferred_variant_adoption&.price : best_price
         logger.debug "Setting display prices for #{order.id}, Results: #{best_price}, Details: #{va_price}"
         result.value.set_display_prices(best_price, va_price)
       end
    end

    if params[:payment_method_id].to_i > 0
      # From orders_controller#update
      # giving order[payments_attributes][][payment_method_id]
      payment = order.payments.valid.find_by(payment_method_id: params[:payment_method_id] )
      if payment.nil?
        update_status = ::Spree::Cart::Update.call(order: order, params:{ payments_attributes:[{ payment_method_id: params[:payment_method_id] }] } )
        logger.debug " .. update w/ payment => #{update_status.success}"
      end
    end

    respond_to do|format|
      format.json { render_order(result) }
      format.js
      format.html do
        next_url = if @variant_adoption && params[:continue_shopping]
            main_app.show_product_by_variant_adoption_path(@variant_adoption)
          elsif @variant && params[:continue_shopping]
            main_app.show_product_by_variant_path(@variant)
          else
            cart_path(token: order.token)
          end
        redirect_to next_url
      end
    end
  end

  protected

  def buyer
    @buyer ||= (spree_current_user || current_spree_user)
  end

  alias_method :current_user, :buyer

  ##
  # spree_current_user could stay nil even though signed in.
  def current_ability
    @current_ability ||= ::Spree::Ability.new(buyer)
  end

  ##
  # Was private in parent class' included OrderConcern module.
  def order_token
    request.headers['X-Spree-Order-Token'] || params[:order_token]
  end

  def spree_current_order
    @spree_current_order ||= find_spree_current_order
  end

  ##
  # Was private in parent class' included OrderConcern module.
  # Modified a bit to use buyer instead of spree_current_user for user
  def find_spree_current_order
    Spree::Api::Dependencies.storefront_current_order_finder.constantize.new.execute(
      store: current_store,
      user: buyer,
      token: order_token,
      currency: current_currency
    )
  end

  # If header or param does not have order_token, this would search
  # for incompete of signed in user and variant's seller; else would create new order.
  # For accuracy, provide both :store_id and :seller_user_id.
  def ensure_order(other_atttributes = {})
    authorize! :create, Spree::Order unless Rails.env.test?

    order = spree_current_order
    if order.nil? && other_atttributes[:store_id].nil? && other_atttributes[:seller_user_id].nil?
      raise ArgumentError.new('Need to specify seller or store')
    end
    if buyer && order.nil?
      order = Spree::Order.incomplete.where(seller_user_id: @variant.user_id, user_id: buyer.id).last
    end
    order ||= Spree::Order.create(
      { currency: current_currency, token: order_token,
        user_id: (spree_current_user || current_spree_user).try(:id)
      }.merge(other_atttributes)
    )
    @spree_current_order ||= order
    params[:order_token] ||= order.token if request.format != 'text/json'
    session[:order_token] = order.token if spree_current_user.nil?
    order
  end

  def load_variant
    @variant_adoption = params[:variant_adoption_id] ? Spree::VariantAdoption.where(id: params[:variant_adoption_id]).first : nil
    if @variant_adoption
      @object = @variant_adoption
      params[:variant_id] = @variant_adoption.variant_id
    end
    @variant = Spree::Variant.find(params[:variant_id])
  end

end
Spree::Api::V2::Storefront::CartController.prepend(Spree::Api::V2::Storefront::CartControllerDecorator) if Spree::Api::V2::Storefront::CartController.included_modules.exclude?(Spree::Api::V2::Storefront::CartControllerDecorator)
