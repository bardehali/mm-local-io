class ChangePaymentMethodAvailableToUsers < ActiveRecord::Migration[6.0]
  def change
    if column_exists? :spree_payment_methods, :available_to_users
      change_column :spree_payment_methods, :available_to_users, :boolean, default: false
    end
  end
end
