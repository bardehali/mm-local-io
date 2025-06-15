module Spree::Admin::OrdersControllerDecorator

  def self.prepended(base)
    base.include ::ControllerHelpers::FileStreamer
    base.include ::Spree::Admin::Shared::AdoptionHelper
    base.include User::MessagesHelper

    base.helper ::Spree::Admin::MoreOrdersHelper
    base.helper ::Admin::StatsHelper

    base.skip_before_action :authorize_admin, only: [:edit, :cancel, :resume, :approve, :resend, :cart, :sales, :show, :update_messages]

    base.before_action :build_conditions, only: [:index, :sales, :mobile_sales]
    base.before_action :load_order, only: [:preview_invoice_email, :show, :update_messages]

    base.before_action :set_before_approve, only: [:approve]
    base.before_action :load_latest_wanted_products, only: [:index, :sales, :mobile_sales, :show]

    base.before_action :load_user_messages, only: [:index, :sales]


  end

  ##
  # Buyer's list of purchases.
  def index
    @search = Spree::Order.preload(:user, line_items: [:product, :variant]).accessible_by(current_ability, :index).ransack(params[:q])

    # lazy loading other models here (via includes) may result in an invalid query
    # e.g. SELECT  DISTINCT DISTINCT "spree_orders".id, "spree_orders"."created_at" AS alias_0 FROM "spree_orders"
    # see https://github.com/spree/spree/pull/3919
    @orders = @search.result(distinct: true).
              page(params[:page]).
              per(params[:per_page] || Spree::Config[:admin_orders_per_page])

    # Restore dates
    params[:q][:created_at_gt] = @created_at_gt
    params[:q][:created_at_lt] = @created_at_lt
  end

  ##
  # Seller's list of orders to him/her.
  def sales
    load_sales

    respond_to do|format|
      format.html
      format.csv { stream_csv_file(@orders, Spree::Order.row_header) }
    end
  end

  def mobile_sales
    load_sales

    respond_to do|format|
      format.html { render layout:'spree/layouts/only_main_content' }
      format.csv { stream_csv_file(@orders, Spree::Order.row_header) }
    end
  end

  ##
  # Seller's and buyer's detail of the order
  def show
    authorize! action, @order
    if (spree_current_user.id == @order.user_id)
      render layout:'spree/layouts/buyer_admin'
    end
    @similar_missed_sales = get_latest_wanted_products(@order.line_items.first.product.taxon_ids.first)
  end

  ##
  # Copied from original gem.
  def approve
    @order.approved_by(try_spree_current_user)
    flash[:success] = Spree.t(:order_approved)
    respond_to do|format|
      format.html { redirect_back fallback_location: spree.edit_admin_order_url(@order) }
      format.js
    end


  end

  ##
  # Change of OrderMailer.confirm_email to order.send_invoice_to_buyer
  def resend
    @order.send_invoice_to_buyer(true)

    flash[:success] = Spree.t(:order_email_resent)
    redirect_back fallback_location: spree.edit_admin_order_url(@order)
  end

  ##
  # Override: does nothing but redirect back to orders
  def set_store
    respond_to do|format|
      format.js { render js:'' }
      format.html { redirect_to edit_admin_order_path(@order) }
    end
  end

  def preview_invoice_email

  end

  def update_messages
    p_param = params.permit(:order_info_selector, :messages_selector, order: [:group_name, :admin_last_viewed_at, :deleted_at])
    logger.debug "| permitted p_param #{p_param[:order]}"
    if p_param[:order]
      p_param[:order][:admin_last_viewed_at] = Time.now if p_param[:order][:admin_last_viewed_at] == 'now'
      logger.debug "| :order = #{p_param[:order] }"
      @order.messages.update_all( p_param[:order].to_hash.symbolize_keys )
    end
    respond_to do|format|
      format.js
    end
  end

  protected

  def load_sales
    @title = Spree.t('admin.sellers.sales')
    @title << (params[:state].present? ? ' - ' + Spree.t("admin.order_state_name.#{params[:state]}") : '')

    if !spree_current_user&.admin?
      params[:q][:seller_user_id_eq] = spree_current_user.id
    else # admin might have many created products w/ testing orders
      @user = params[:q][:seller_user_id_eq] ? Spree::User.find_by(id: params[:q][:seller_user_id_eq] ) : nil
      if @user && !@user.admin?
        params[:q][:seller_user_id_eq] = @user.id
      end
    end

    q_select = "#{Spree::Order.table_name}.*"

    q = Spree::Order.preload(:user, line_items: [:product, :variant])
    q = q.with_product_id(params[:with_product_id]) if params[:with_product_id]
    if %w(messages complaints).include?(params[:state])
      q = q.with_complaint
    elsif %w(need_tracking_number).include?(params[:state])
      q = q.with_need_tracking_number
    elsif %w(paid_need_tracking).include?(params[:state])
      q_select << ", #{::User::Stat.table_name}.value"
      q = q.paid_need_tracking.joins(:count_of_paid_need_tracking)
    elsif %w(pending_payment payment).include?(params[:state])
      q = q.without_complaint_or_tracking_number
    elsif %w(comments reports).include?(params[:state])
      q = q.send("with_#{params[:state] }".to_sym)
    end

    if !spree_current_user&.admin?
      q = q.with_provided_tracking_number if %w(complete provided_tracking_number).include?(params[:state])
    end
    @search = q.ransack(params[:q])

    # lazy loading other models here (via includes) may result in an invalid query
    # e.g. SELECT  DISTINCT DISTINCT "spree_orders".id, "spree_orders"."created_at" AS alias_0 FROM "spree_orders"
    # see https://github.com/spree/spree/pull/3919
    @orders = @search.result(distinct: true).
              includes(:user, :payments, :messages, seller:[:role_users], line_items:[:product, variant:[:option_values] ] ).
              select(q_select).
              page(params[:page]).
              per(params[:per_page] || Spree::Config[:admin_orders_per_page])

    # Restore dates
    params[:q][:created_at_gt] = @created_at_gt
    params[:q][:created_at_lt] = @created_at_lt
  end

  ##
  # Refactored out from original index.
  # This allows to distinguish b/w index method (buyer) and sales method (seller)
  def build_conditions
    params.permit!
    params[:q] ||= {}

    params[:q][:completed_at_not_null] ||= '1' if Spree::Config[:show_only_complete_orders_by_default]
    @show_only_completed = params[:state] != 'cart'
    if %w(paid_need_tracking).include?(params[:state])
      # params[:q][:s] ||= 'count_of_paid_need_tracking_value desc' if params[:q][:s].blank?
    end
    params[:q][:s] ||= @show_only_completed ? 'completed_at desc' : 'created_at desc' if params[:q][:s].blank?
    params[:q][:completed_at_not_null] = '' unless @show_only_completed

    # As date params are deleted if @show_only_completed, store
    # the original date so we can restore them into the params
    # after the search
    @created_at_gt = params[:q][:created_at_gt]
    @created_at_lt = params[:q][:created_at_lt]

    params[:q].delete(:inventory_units_shipment_id_null) if params[:q][:inventory_units_shipment_id_null] == '0'

    if params[:q][:created_at_gt].present?
      params[:q][:created_at_gt] = begin
                                      Time.zone.parse(params[:q][:created_at_gt]).beginning_of_day
                                    rescue StandardError
                                      ''
                                    end
    end

    if params[:q][:created_at_lt].present?
      params[:q][:created_at_lt] = begin
                                      Time.zone.parse(params[:q][:created_at_lt]).end_of_day
                                    rescue StandardError
                                      ''
                                    end
    end

    if @show_only_completed
      params[:q][:completed_at_gt] ||= params[:q].delete(:created_at_gt)
      params[:q][:completed_at_lt] ||= params[:q].delete(:created_at_lt)
    end

    if params[:state].present?
      if %w(all messages complaints need_tracking_number pending_payment payment paid_need_tracking comments reports).include?(params[:state])
        # params[:q][:state_in] = %w(payment delivery)
      else
        params[:q][:state_eq] = params[:state]
      end
    end

    if params[:store_payment_method_id] && (@store_payment_method = Spree::StorePaymentMethod.find_by(id: params[:store_payment_method_id]) )
      seller_user_ids = @store_payment_method.same_store_payment_methods.collect(&:user_id)
      if seller_user_ids.present?
        @users = Spree::User.with_deleted.where(id: seller_user_ids).all
        params[:q][:seller_user_id_in] = seller_user_ids
        params[:keywords] = @store_payment_method.account_id_in_parameters
      end
    end
    logger.debug "| final params after build_conditions: #{params}"
  end

  def load_user_messages
    logger.debug "| load_user_messages or not? #{spree_current_user&.seller?}"
    if spree_current_user&.seller?
      load_user_notifications
    end
  end

  ##
  # When seller approves the order, would mean received payment.
  def set_before_approve
    @order ||= load_order
    if @order.seller_user_id == spree_current_user&.id
      @order.payment_total ||= @order.total
      @order.payment_state ||= 'paid'
    end
  end

end
Spree::Admin::OrdersController.prepend(Spree::Admin::OrdersControllerDecorator) if Spree::Admin::OrdersController.included_modules.exclude?(Spree::Admin::OrdersControllerDecorator)
