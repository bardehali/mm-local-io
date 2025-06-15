class AddViewCountToLineItems < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::LineItem.table_name, :current_view_count, :integer, default: nil
  end

  def down
    remove_column_if_exists ::Spree::LineItem.table_name, :current_view_count
  end
end
