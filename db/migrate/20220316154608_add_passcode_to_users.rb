class AddPasscodeToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :spree_users, :passcode, :string, length: 128
    add_index_unless_exists :spree_users, :passcode
  end

  def down
    remove_index_if_exists :spree_users, :password
    remove_column_if_exists :spree_users, :password
  end
end
