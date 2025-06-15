module Spree::OrdersControllerDecorator
  def self.prepended(base)

  end
end

class Spree::OrdersController

  include Spree::Core::ControllerHelpers::MoreOrder # although StoreController already has
  include ControllerHelpers::SellerManager
  helper ::Spree::MorePaymentsHelper

  before_action :find_all_orders_by_token_or_user, only: [:edit]
  before_action :load_order, only: [:help, :upload_image, :show_message, :update_channel, :create_message]
  before_action :respond_according_to_order_state, only: [:show]

  skip_before_action :set_current_order, only: [:index, :recent_sales]
  skip_before_action :check_authorization, only: [:index]

  layout 'spree/layouts/checkout'


  def index
    @page_title = @title = I18n.t('spree.my_orders')
    params[:q] ||= {}
    params[:q][:user_id_eq] = spree_current_user&.id
    @search = Spree::Order.ransack(params[:q])
    @orders = @search.result.
      includes(:user, :seller, line_items:[:product => [:best_variant], variant:[:option_values=>[:option_type] ] ]).
      order('completed_at desc').page(params[:page]).per(params[:limit] || Spree::Config[:admin_products_per_page] )

    respond_to do|format|
      format.html
    end
  end

  ##
  # Variation of index_with_state
  def recent_sales
    params[:state] = 'complete'
    load_orders_with_state

    respond_to do|format|
      # format.json { render json: @orders.as_json } # this would expose user info
      format.js
    end
  end

  def edit
    if @orders
      @orders = @orders.to_a.find_all{|o| o.seller_user_id == params[:seller_user_id] } if params[:seller_user_id].to_i > 0
      @orders = @orders.to_a.find_all{|o| o.token == order_token } if order_token.present?
    end
    logger.debug "| orders: #{@orders.collect(&:to_s)}"
    respond_to do|format|
      format.html { }
      format.json { render json: @orders }
    end
  end

  def help
    #if @order.messages.complaint_or_higher_level.count > 0 && !Rails.env.development?
    #  redirect_to order_path(@order, t: Time.now.to_i)
    #else
    #end
  end

  def upload_image
    params.permit(order:[:proof_of_payment] )
    # authorize! :update, @order
    if (order_param = params[:order]) && spree_current_user&.id == @order.user_id
      @order.proof_of_payment = order_param[:proof_of_payment] if order_param[:proof_of_payment]
      @order.save
    end
    respond_to do|format|
      format.html { redirect_to [params[:return_url], order_path(@order) ].find(&:present?) }
      format.js
    end
  end

  def show_message
    @message = @order.messages.where(id: params[:message_id]).first
    if @message
      render template:'spree/orders/show_message'
    else
      flash[:warning] = 'Message not found'
      redirect_to order_path(@order)
    end
  end

  def create_message
    params.permit(:type, :references, :order_id, :comment, :parent_message_id, :image, :amount, :container)

    begin
      type_class = ( 'User::' + ( params[:type] || 'order_message').classify ).constantize
    rescue NameError
      type_class = User::OrderMessage
    end
    common_conds = { record_type: @order.class.to_s, record_id: @order.id,
      sender_user_id: spree_current_user&.id,
      recipient_user_id: @order.the_other_user_id(spree_current_user&.id) }
    @message = type_class.where(common_conds).where('created_at > ?', 1.hour.ago).last if type_class.level >= ::User::Message::COMPLAINT_LEVEL
    @message ||= type_class.where(common_conds.merge(comment: params[:comment]&.strip) ).last
    if @message
      logger.debug "| #{spree_current_user&.to_s} already created #{type_class} at #{@message.created_at}"
      if params[:comment].present? && params[:comment]&.strip != @message.comment
        @message.references = params[:references] if params[:references].present?
        @message.comment = [@message.comment, params[:comment] ].reject(&:blank?).join('  ')
        @message.image = params[:image] if params[:image]
        @message.save
      end
    end
    @message ||= type_class.create(type: type_class, record_type: @order.class.to_s, record_id: @order.id,
      sender_user_id: spree_current_user&.id,
      recipient_user_id: @order.the_other_user_id(spree_current_user&.id),
      parent_message_id: params[:parent_message_id],
      references: params[:references], comment: params[:comment],
      image: params[:image], amount: params[:amount]
     )

    if @message.valid?
      if params[:attach_proof_of_payment]
        @order.proof_of_payment = @message.image if @message.image.url.present?
        @order.save
      end

      respond_to do|format|
        format.js { render 'create_message_by_upload_image.js.erb' }
        format.html do
          goto_url = if params[:return_url].present?
            params[:return_url]
          elsif (mailto_url = draft_mailto_url_if_needed(@message, @order, :controller) ).present?
            mailto_url
          else
            if (spree_current_user&.id == @order.seller_user_id)
              admin_order_path(@order)
            else
              order_show_message_path(id: @order.number, message_id: @message.id)
            end
          end
          redirect_to goto_url
        end
      end
    else
      logger.debug "| message errors: #{@message.errors.messages}"
      render template:'spree/orders/help'
    end
  end

  helper_method :draft_mailto_url_if_needed, :draft_whatsapp_url_if_needed

  def respond_according_to_order_state
    if @current_order && @current_order.completed_at.nil?
      redirect_to checkout_state_path(state: @current_order.state, id: @current_order.id)
    end
  end

end
Spree::OrdersController.prepend(Spree::OrdersControllerDecorator) if Spree::OrdersController.included_modules.exclude?(Spree::OrdersControllerDecorator)
