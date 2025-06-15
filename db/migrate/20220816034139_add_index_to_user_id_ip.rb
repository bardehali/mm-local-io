class AddIndexToUserIdIp < ActiveRecord::Migration[6.0]
  def up
    add_index_unless_exists Ioffer::User.table_name, [:user_id, :ip], name:'idx_users_user_id_ip'
  end

  def down
    remove_index_if_exists Ioffer::User.table_name, [:user_id, :ip]
  end
end
