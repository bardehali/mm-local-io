class AddOtherPaymentMethodsLikeXoom < ActiveRecord::Migration[6.0]
  def change
    %w(Remitly Xendpay Xoom).each do|pm_name|
      Spree::PaymentMethod.find_or_create_by(name: pm_name.to_underscore_id) do|pm|
        pm.type = 'Spree::PaymentMethod::General'
        pm.description = pm_name
        pm.active = true
        pm.available_to_users = true
        pm.available_to_admin = true
        pm.display_on = 'both'
      end
    end
  end
end
