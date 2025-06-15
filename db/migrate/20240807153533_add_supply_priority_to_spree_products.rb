class AddSupplyPriorityToSpreeProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_products, :supply_priority, :integer, default: 0, null: false
  end
end
