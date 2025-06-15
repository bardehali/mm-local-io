class EnsurePaymentMethodForPaypal < ActiveRecord::Migration[6.0]
  def change
    payment_method = Spree::PaymentMethod.find_or_create_by(name:'paypal')
    if payment_method
      payment_method.update(type: "Spree::Gateway::PayPalGateway")

    else
      payment_method = Spree::PaymentMethod.create(type: "Spree::Gateway::PayPalGateway", 
        name:'paypal', description:'PayPal', active: true, available_to_users: true, 
        available_to_admin: true, display_on:'both')
    end
  end
end
