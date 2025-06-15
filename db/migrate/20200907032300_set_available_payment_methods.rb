class SetAvailablePaymentMethods < ActiveRecord::Migration[6.0]
  def change
    Spree::PaymentMethod.all.update_all(available_to_users: false)
    Spree::PaymentMethod.where(name: %w(paypal alipay transferwise)).update_all(available_to_users: true)

    Retail::Site.all.where(user_selectable: false)
    Retail::Site.where(name: ['aliexpress', 'dhgate']).update_all(user_selectable: true)
  end
end
