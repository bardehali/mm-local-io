require 'countries'

module Spree::Core::ControllerHelpers::MoreOrder
  extend ActiveSupport::Concern

  included do
    helper_method :product_to_represent_order
  end

  def current_order(options = {})
    options[:create_order_if_necessary] ||= false
    options[:includes] ||= true

    if @current_order
      @current_order.last_ip_address = ip_address
      return @current_order
    end

    @current_order = find_order_by_token_or_user(options, true)

    if options[:create_order_if_necessary] && (@current_order.nil? || @current_order.completed?)
      @current_order = Spree::Order.create!(current_order_params)
      @current_order.associate_user! try_spree_current_user if try_spree_current_user
      @current_order.last_ip_address = ip_address
    end

    logger.info "| MoreOrder.current_order\n  #{@current_order.try(:to_s)}"

    @current_order
  end

  ##
  # @includes [Array or Hash or nil] to load less records by includes, provide own.
  def find_all_orders_by_token_or_user(includes = nil)
    unless @orders
      includes ||= [:seller, :promotions, :line_items, line_items: { variant: [:images, :product, option_values: :option_type ] } ]
      @orders = Spree::Order.incomplete.includes(*includes)
      if spree_current_user && order_token.blank?
        @orders = @orders.where(user_id: spree_current_user.id)
      else
        @orders = @orders.where(token: Rails.env.test? ? params[:token] : (order_token || cookies.signed[:token]) )
      end
      @orders = @orders.where(seller_user_id: params[:seller_user_id]) if params[:seller_user_id].to_i > 0
    end
    @orders
  end

  ##
  # Override of Spree::Api::V2::Storefront::OrderConcern
  # Parent would merge any incomplete orders into one, which is wrong for us.
  def set_current_order
    if @current_order.nil?
      order_params = nil
      if params[:id]
        order_params = { (params[:id].to_s =~ /\A\d+\Z/ ? :id : :number) => params[:id] }
      elsif order_token
        order_params = { token: order_token }
      end
      @current_order = Spree::Order.includes(:store, :payments, :line_items=>[:variant]).find_by(order_params) if order_params
    end


    order = @current_order || current_order(params)
    logger.debug "| OrderDecor.set_current_order: #{order.to_s }\n| title: #{order&.title}\n| email: #{order&.email}"

    if @current_order && @current_order&.user_id.nil? && try_spree_current_user && order_token == @current_order&.token
      logger.debug "| associate order to #{spree_current_user.to_s}"
      @current_order.associate_user!(spree_current_user)
    end
    @title = "Order Details" || Spree.t('cart')

    if order && action_name.to_sym == :show
      authorize! :show, order, cookies.signed[:token]
    elsif order
      authorize! :edit, order, cookies.signed[:token]
    else
      # authorize! :create, Spree::Order
    end
  end

  def load_orders_with_state(state = nil)
    params[:q] ||= {}
    params[:q][:state_eq] = state || params[:state]
    params[:q][:id_gt] = params[:last_order_id] if params[:last_order_id]

    @search = Spree::Order.ransack(params[:q])
    @orders = @search.result.includes(:user, line_items:[product:[ :variant_images] ] ).order('id desc').
      page(params[:page]).limit(params[:limit] || 6).reverse
  end

  ##
  # Pick one product that display the order in one, such as preferred image.
  def product_to_represent_order(order)
    product = nil
    order.line_items.each do|line_item|
      unless product
        product = line_item.product if line_item.product.variants_including_master.find{|v| v.images.count > 0 }
      end
      break if product
    end
    product || order.line_items.first&.product
  end

  ##
  # Decide whether @message.type_id has the type that has draft template for mail_to: URL.
  # @controller_or_page_level [Boolean] (:controller or :page) some message type do not need
  #   going to next page to load mailto link, so would return nil.
  def draft_mailto_url_if_needed(message, order, controller_or_page_level = :page)
    one_payment = order.payments.valid.last
    store_payment_method = order.store_payment_methods[one_payment.payment_method_id]
    payment_method = store_payment_method&.payment_method
    option_values_string = order.line_items.first.variant.option_values_for_display.join('%0A')

    # Common values
    mailto_start = "mailto:#{store_payment_method&.account_id_in_parameters || order.seller&.email}"
    cc = "?cc=#{order.seller&.email},portal@ioffer.com"
    subject_suffix = "#{order.number}%20~%20#{order.line_items.first.name}"

    order_s = "%2Forders%2F#{order.number}%0A%0AiOffer%20Order%20#{order.number}"
    order_s << "%0D%0A#{ (order.ship_address&.state) }%2C%20#{ (order.ship_address&.country) }"
    order_s << "%0D%0A%0D%0A#{ order.line_items.first.name }%0D%0A#{option_values_string}"
    order_s << "%0D%0A%0APrice%3A%20#{ order.display_total.to_html }%0D%0APayment%3A%20#{payment_method&.description}"
    order_s << "%0D%0A%0D%0ABuyer%3A%20#{ (order.ship_address.to_s).gsub("<br/>", '%0D') }"
    if message.nil?
      s = mailto_start
      s << cc
      s << "&subject=ORDER%20-%20#{order.number}%20-%20iOffer%20Sales"
      s << "&body=Hello,%20I%20just%20ordered%20\"#{order.line_items.first.name}\"%20from%20you%20on%20iOffer."
      s << "%0A%20I%20would%20like%20to%20pay%20with%20#{payment_method&.description}."
      s << "%0APlease%20Send%20Payment%20Instructions.%20%0A%0A%0A%0A"
      s << "%0AOrder%20Information%20========================="
      s << "%0A%0Ahttps%3A%2F%2Fioffer.com%2Fadmin%2Forders%2F#{order.number}%0A"
      s << "%0D%0A%0D%0A#{ order.line_items.first.name }%0D%0A#{option_values_string}"
      s << "%0APrice%3A%20#{ order.display_total.to_html }%0D%0APayment%3A%20#{payment_method&.description}"
      s << "%0D%0A%0D%0ABuyer%3A%20#{ (order.ship_address.to_s).gsub("<br/>", '%0D') }"
    elsif message&.type_id == 'order_help_with_payment'
      s = mailto_start
      s << cc
      s << "&subject=PAYMENT%20HELP%20~%20#{ subject_suffix }"
      s << "&body=I%20NEED%20HELP%20WITH%20PAYMENT%3A%20%20#{payment_method&.description&.upcase}"
      s << "%0A%0Ahttps%3A%2F%2Fioffer.com%2Fadmin"
      s << order_s
      controller_or_page_level == :page ? s : nil
    elsif message&.type_id == 'order_other_question'
      s = mailto_start
      s << cc
      s << "&subject=QUESTION%20~%20#{subject_suffix}"
      s << "&body=%0A%0Ahttps%3A%2F%2Fioffer.com%2Fadmin%"
      s << order_s
      controller_or_page_level == :controller ? s : nil
    elsif message&.is_a?(User::OrderNeedTrackingNumber) || (message.is_a?(User::OrderComplaint) && message.references == 'order_need_tracking_number')
      s = mailto_start
      s << cc
      subject_prefix = 'TRACKING%20INFO%20~%20'
      subject_prefix = 'INCORRECT%20' + subject_prefix if message.is_a?(User::OrderBrokenTrackingNumber)
      s << "&subject=#{subject_prefix}#{order.number}"
      s << "%20~%20YOUR%20MUST%20RESPOND" if message.recipient_must_respond?
      s << "&body=I%20NEED%20TRACKING%2FSHIPPING%20INFO%3A%0A%0A"
      s << "The tracking information supplied is not correct.%0A%0A" if message.is_a?(User::OrderBrokenTrackingNumber)
      s << '=' * 40 + '%0A'
      s << "https%3A%2F%2Fioffer.com%2Fadmin/orders/#{order.number}%0A"
      s << '=' * 40 + '%0A'
      if message&.recipient_must_respond?
        s << "#{message.recipient.login} YOU MUST RESPOND%0A%0A%0A"
      end
      if message&.comment.present?
        s << "Note From Buyer:%0A#{message.comment}%0A%0A"
      end

      s << "iOffer%20Order%20#{order.number}"
      s << "%0D%0A%0D%0ABuyer%3A%20%0A#{ (order.ship_address.to_s).gsub("<br/>", '%0D') }"

      controller_or_page_level == :page ? s : nil
    else
      nil
    end
  end

  def draft_whatsapp_url_if_needed(order, controller_or_page_level = :page)
    one_payment = order.payments.valid.last
    store_payment_method = order.store_payment_methods[one_payment.payment_method_id]
    payment_method = store_payment_method&.payment_method
    option_values_string = order.line_items.first.variant.option_values_for_display.join('%0A')

    country = CGI.escape(order.ship_address&.country.to_s)
    #flag = country_to_flag(country)
    flag = "🇦🇺"
    order_type = CGI.escape(order&.line_items&.first&.product.taxons&.last&.meta_keywords)

    # Common values for WhatsApp URL
    whatsapp_number = order&.seller&.store&.whatsapp.to_s.strip
    whatsapp_number = whatsapp_number.sub(/\A\+/, '') if whatsapp_number.present?
    # Append order link for reference

    message = "#{order_type}%20Order%20|%20#{order.number}%20|%20Buyer%20from%20#{country}%0A=======================%0A%0AOrder%20Information%20=======================%0AProduct%20Name:%20#{order.line_items.first.name}%0APrice:%20#{order.display_total.to_html}%0APayment%20Method:%20#{payment_method&.description}%0A%0ABuyer:%20#{order.ship_address.to_s.gsub("<br/>", '%0D')}"

    order_link = "https://ioffer.com/admin/orders/#{order.number}?utm_trx=wa"
    # Construct the full WhatsApp URL
    whatsapp_url = "https://api.whatsapp.com/send/?phone=#{whatsapp_number}&text=#{message}%0A%0A#{order_link}%0A%0A=======================%0A%0A"

    controller_or_page_level == :page ? whatsapp_url : nil
  end

  def update_channel
    if @order.present?
      channel_type = params[:channel] # Get channel type from request (whatsapp or email)

      if ["whatsapp", "email"].include?(channel_type) # Only allow valid channel values
        if @order.update(channel: channel_type)
          Rails.logger.info "✅ Order #{@order.number} channel updated to #{channel_type.capitalize}"
          head :ok
        else
          Rails.logger.error "❌ Failed to update channel: #{@order.errors.full_messages.join(', ')}"
          render json: { error: @order.errors.full_messages }, status: :unprocessable_entity
        end
      else
        Rails.logger.error "❌ Invalid channel type received: #{channel_type}"
        render json: { error: "Invalid channel type" }, status: :bad_request
      end
    else
      Rails.logger.error "❌ No current order found"
      render json: { error: "No current order found" }, status: :not_found
    end
  end

  protected

  def current_order_params
    { currency: current_currency, token: cookies.signed[:token], user_id: try_spree_current_user.try(:id) }
  end

  #Country to emoji flag.
  # def country_to_flag(country_name)
  #   country = ISO3166::Country.find_country_by_name(country_name)
  #   return "" unless country && country.alpha2
  #
  #   # Convert the country code to a flag emoji
  #   country.alpha2.chars.map { |char| (char.ord + 127397).chr(Encoding::UTF_8) }.join
  # end

  # Either from session or variant param keys
  def order_token
    session[:order_token] || params[:order_token] || params[:token]
  end

  # Replacement of Spree::Api::V2::Storefront::OrderConcern

end
