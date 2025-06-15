class AddInvoiceLastSentAtToOrders < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :spree_orders, :invoice_last_sent_at, :datetime
  end

  def down
    remove_column_if_exists :spree_orders, :invoice_last_sent_at
  end
end
