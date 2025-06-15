class AddBrowseDisplayPriceToSpreeLineItems < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_line_items, :browse_display_price, :decimal, precision: 10, scale: 2, default: 0.0, null: false
  end
end
