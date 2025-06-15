class AddApprovedToPayment < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :spree_payments, :approved, :boolean, default: false
    add_index_unless_exists :spree_stores, :name
  end

  def down
    remove_column_if_exists :spree_payments, :approved
    remove_index_if_exists :spree_stores, :name
  end
end

