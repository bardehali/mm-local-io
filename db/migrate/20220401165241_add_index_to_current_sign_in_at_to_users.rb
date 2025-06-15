class AddIndexToCurrentSignInAtToUsers < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists Spree::User.table_name, :current_sign_in_at
  end

  def down
    remove_index_if_exists Spree::User.table_name, :current_sign_in_at
  end
end
