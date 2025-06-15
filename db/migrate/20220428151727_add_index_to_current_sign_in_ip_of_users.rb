class AddIndexToCurrentSignInIpOfUsers < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists Spree::User.table_name, [:deleted_at, :current_sign_in_ip], name: 'idx_spree_users_current_signed_in_ip'
  end

  def down
    remove_index_if_exists Spree::User.table_name, [:deleted_at, :current_sign_in_ip]
  end
end
