class AddHighestMessageLevelToOrders < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::Order.table_name, :highest_message_level, :integer, default: 0
    ::Spree::Order.complete.joins(:one_message).in_batches do|subq|
      subq.each do|o|
        o.update_highest_message_level!
      end
    end
  end

  def down
    remove_column_if_exists ::Spree::Order.table_name, :highest_message_level
  end
end
