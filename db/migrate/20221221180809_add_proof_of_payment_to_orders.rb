class AddProofOfPaymentToOrders < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::Order.table_name, :proof_of_payment, :string, limit: 255
  end

  def down
    remove_column_if_exists Spree::Order.table_name, :proof_of_payment
  end
end
