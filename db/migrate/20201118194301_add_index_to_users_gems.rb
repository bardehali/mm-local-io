class AddIndexToUsersGems < ActiveRecord::Migration[6.0]
  def change
    add_index_unless_exists :users, :gms
  end
end
