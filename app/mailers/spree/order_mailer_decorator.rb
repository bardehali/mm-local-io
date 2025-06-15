module Spree::OrderMailerDecorator
  def self.prepended(base)
    base.include Spree::BaseMailerDecorator
    base.helper Spree::ProductsHelper
    base.helper Spree::MorePaymentsHelper
    base.helper Spree::BaseMailerDecorator::HelperMethods
    base.layout 'mailer'
  end

  FROM_ADDRESS = 'iOffer Sales <noreply@mail.ioffer.com>' unless defined?(FROM_ADDRESS)

  ##
  # Expected parameters: :order, :subject_prefix
  def invoice_to_buyer
    set_order_instance_variables

    @url = URI.join( @host, Spree::Core::Engine.routes.url_helpers.order_help_path(@order) )
	  @top_header = "#{Spree.t('order') } - #{ @order.number }"

    mail(from: FROM_ADDRESS, to: @order.user.email, 
      subject:"#{@subject_prefix}#{@order.user.username} #{I18n.t('order.your_order_is_confirmed')}!")
  end

  def new_order_to_seller
    set_order_instance_variables
    @user = @order.seller
    args = {
      from: FROM_ADDRESS,
      to: @order.seller.email, 
      subject:"#{@subject_prefix}#{@order.seller.username} #{I18n.t('spree.new_order')} #{@order.number}"
    }
    @paypal_account_id = @order.store.store_payment_methods.where(payment_method_id: Spree::PaymentMethod.paypal.id).first&.account_id_in_parameters
    args[:cc] = @paypal_account_id if @paypal_account_id.present? && @paypal_account_id.valid_email?

    mail(args)
  end

  ##
  # Required params
  #   :message
  def tracking_to_buyer
    set_order_instance_variables
    @message = params[:message]
    @tracking_number = [@message&.comment, @order.latest_tracking_number].find(&:present?)
    
    @url = URI.join( @host, Spree::Core::Engine.routes.url_helpers.order_help_path(@order) )
	  @top_header = "#{Spree.t('order') } - #{ @order.number }"

    mail(from: FROM_ADDRESS, to: @order.user.email, 
      subject:"#{@subject_prefix}#{@order.user.username} #{I18n.t('message.the_seller_has_shipped_your_item')}!")
  end

  private

  def set_order_instance_variables
    @order = params[:order]
    @user = @order.user
    @payment_method = @order.payments.first&.payment_method
    @host = Rails.application.config.action_mailer.default_url_options[:host]

    @subject_prefix = params[:subject_prefix]
    @subject_prefix << ' ' if @subject_prefix.present?
  end

end

Spree::OrderMailer.prepend(Spree::OrderMailerDecorator) if Spree::OrderMailer.included_modules.exclude?(Spree::OrderMailerDecorator)