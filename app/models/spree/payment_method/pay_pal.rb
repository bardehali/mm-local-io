module Spree
  class PaymentMethod::PayPal < Spree::PaymentMethod
    def payment_source_class
      Spree::Gateway::PayPalGateway
    end

    def supports?(source)
      true
    end

    def source_required?
      false
    end

  end
end