class AddLastActiveAtToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::User.table_name, :last_active_at, :datetime
    add_index_unless_exists ::Spree::User.table_name, [:deleted_at, :last_active_at], name:'idx_susers_deleted_last_active_at'
    ::Spree::User.update_all("last_active_at = current_sign_in_at")
    ::Spree::User.where("last_active_at is null").update_all("last_active_at = created_at")

  end

  def down
    remove_index_if_exists ::Spree::User.table_name, [:deleted_at, :last_active_at]
    remove_column_if_exists ::Spree::User.table_name, :last_active_at
  end
end
