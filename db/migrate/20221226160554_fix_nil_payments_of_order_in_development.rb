class FixNilPaymentsOfOrderInDevelopment < ActiveRecord::Migration[6.0]
  def change
    if Rails.env.development?
      puts "Fixing nil payments of orders for development"
      Spree::Order.complete.left_joins(:payments).where("spree_payments.id IS NULL").each do|o| 
        o.payments.create( payment_method_id:(Spree::PaymentMethod.paypal || Spree::PaymentMethod.first).id, state:'checkout' )
      end
    end
  end
end
