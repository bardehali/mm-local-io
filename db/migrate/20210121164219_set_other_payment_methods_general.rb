class SetOtherPaymentMethodsGeneral < ActiveRecord::Migration[6.0]
  def change
    Spree::PaymentMethod.where("type is null or type=''").update_all(type: 'Spree::PaymentMethod::General')
  end
end
