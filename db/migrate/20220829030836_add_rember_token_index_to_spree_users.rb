class AddRemberTokenIndexToSpreeUsers < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists ::Spree::User.table_name, [:deleted_at, :remember_token], name:'idx_del_remtoken_users'
  end

  def down
    remove_index_if_exists ::Spree::User.table_name, [:deleted_at, :remember_token]
  end
end
