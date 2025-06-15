##
# Stores changed to individual seller-owned products (variants), so purcahses
# need to have orders associated to actual seller store, but not single pending
# order for entire site.  Methods in this controller that use checkout_state_path
# need to include order ID.
module Spree::CheckoutControllerDecorator

  def self.prepended(base)
    base.helper Spree::MorePaymentsHelper

    base.before_action :check_buyer_permissions
  end

  # Updates the order and advances to the next state (when possible.)
  def update
    if @order.update_all_from_params(params, permitted_checkout_attributes, request.headers.env)
      @order.temporary_address = !params[:save_user_address]
      unless @order.next || @order.completed?
        logger.info "** Order #{@order.to_s} no next step ---------------------"
        flash[:error] = @order.errors.full_messages.join("\n")
        redirect_to(checkout_state_path(id: @order.id, state: @order.state)) && return
      end

      @order.check_to_auto_jump unless @order.completed?
      if @order.completed?
        @current_order = nil
        flash['order_completed'] = true
        if @order.seller.phantom_seller?
          redirect_to completion_route({ utm_term: 'trx', utm_source: 'cspr' })
        elsif @order.seller.hp_seller?
          redirect_to completion_route({ utm_term: 'trx', utm_source: 'hp' })
        else
          redirect_to completion_route({ utm_term: 'trx', utm_source: 'aops' })
        end
      else
        redirect_to checkout_state_path(id: @order.id, state: @order.state)
      end
    else
      render :edit
    end
  end

  ##
  # Added required to login or sign up for guest to checkout order
  def ensure_checkout_allowed
    logger.debug "| @order.checkout_allowed? #{@order&.checkout_allowed?}"
    if spree_current_user.nil?
      session['spree_user_return_to'] = request.fullpath
      logger.debug "| to return #{ session['spree_user_return_to'] }"
      if @order&.user_id.nil?
        redirect_to registration_path
      else
        redirect_to login_path
      end
    else
      redirect_to spree.cart_path unless @order.checkout_allowed?
    end
  end

  private

  def unknown_state?
    (params[:state] && !@order.has_checkout_step?(params[:state])) ||
      (!params[:state] && !@order.has_checkout_step?(id: @order.id, state: @order.state))
  end

  def ensure_valid_state
    if @order.state != correct_state && !skip_state_validation?
      flash.keep
      @order.update_column(:state, correct_state)
      redirect_to checkout_state_path(id: @order.id, state: @order.state)
    end
  end


  def ensure_valid_state_lock_version
    if params[:order] && params[:order][:state_lock_version]
      changes = @order.changes if @order.changed?
      @order.reload.with_lock do
        unless @order.state_lock_version == params[:order].delete(:state_lock_version).to_i
          flash[:error] = Spree.t(:order_already_updated)
          redirect_to(checkout_state_path(id: @order.id, state: @order.state)) && return
        end
        @order.increment!(:state_lock_version)
      end
      @order.assign_attributes(changes) if changes
    end
  end

  def set_state_if_present
    if params[:state]
      redirect_to checkout_state_path(id: @order.id, state: @order.state) if @order.can_go_to_state?(params[:state]) && !skip_state_validation?
      @order.state = params[:state]
    end
  end

  def add_store_credit_payments
    if params.key?(:apply_store_credit)
      add_store_credit_service.call(order: @order)

      # Remove other payment method parameters.
      params[:order].delete(:payments_attributes)
      params[:order].delete(:existing_card)
      params.delete(:payment_source)

      # Return to the Payments page if additional payment is needed.
      redirect_to checkout_state_path(id: @order.id, state: @order.state) and return if @order.payments.valid.sum(:amount) < @order.total
    end
  end

  def remove_store_credit_payments
    if params.key?(:remove_store_credit)
      remove_store_credit_service.call(order: @order)
      redirect_to checkout_state_path(id: @order.id, state: @order.state) and return
    end
  end

  def check_buyer_permissions
    if @order.user && @order.user.too_many_orders_recently?
      @order.errors.add(:base, t('order.account_under_review_check_back_later'))
    end
  end

end

Spree::CheckoutController.prepend(Spree::CheckoutControllerDecorator) if Spree::CheckoutController.included_modules.exclude?(Spree::CheckoutControllerDecorator)
