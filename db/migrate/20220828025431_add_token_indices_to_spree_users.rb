class AddTokenIndicesToSpreeUsers < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists ::Spree::User.table_name, [:deleted_at, :confirmation_token], name:'idx_susers_deleted_at_conftoken'
  end

  def down
    remove_index_if_exists ::Spree::User.table_name, [:deleted_at, :confirmation_token]
  end
end
