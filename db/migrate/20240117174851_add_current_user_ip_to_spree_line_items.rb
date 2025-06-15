class AddCurrentUserIpToSpreeLineItems < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_line_items, :request_ip, :string
  end
end
