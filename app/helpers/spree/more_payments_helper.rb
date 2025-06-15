module Spree
  module MorePaymentsHelper

    AVAILABLE_PAYMENT_METHOD_ICONS = %w(
      alipay apple_pay ipaylinks scoinpay transferwise	worldpay paypal	wechat
      bitcoin	paysend	trans ping western_union
    )

    def payment_method_icon(payment_method, version = nil)
      pm_name = payment_method.name.downcase.gsub(/(\s+)/, '_')
      return '' if AVAILABLE_PAYMENT_METHOD_ICONS.exclude?(pm_name)

      asset_path( ['payment_methods', version, "#{pm_name}.png"].compact.join('/') )
    rescue Sprockets::Rails::Helper::AssetNotFound
      ''
    end

    ##
    # @return [Spree::StorePaymentMethod]
    def store_payment_method(order, payment_method)
      @store_payment_methods ||= order.store_payment_methods
      @store_payment_methods[payment_method.id]
    end

    ##
    # @return [Spree::StorePaymentMethod]
    def payment_method_instruction(order, payment_method)
      store_payment_method(order, payment_method).try(:instruction)
    end

    ##
    # Whether all line items' variants are created by real users.
    def has_all_real_sellers?(order)
      order.line_items.includes(:variant).all.all?{|line_item| line_item.variant&.owned_by_anyone? }
    end

    # @return [Spree::StorePaymentMethod]
    def store_payment_method_of(store, payment_method)
      store.store_payment_methods.find_by(payment_method_id: payment_method.id)
    end

    ##
    # Whether we've implemented pay by this @payment_method form.
    def has_pay_form?(payment_method)
      # [Spree::PaymentMethod::PayPal, Spree::Gateway::PayPalGateway].include?(payment_method.class)
      false
    end

    ##############
    # UI

    ##
    # Whether 
    def can_process_all_states?(order)
      order.state_changes.blank?
    end

  end
end