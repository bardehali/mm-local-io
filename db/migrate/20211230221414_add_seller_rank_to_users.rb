class AddSellerRankToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::User.table_name, :seller_rank, :integer, default: 0
    add_index_unless_exists Spree::User.table_name, :seller_rank, name: 'users_seller_rank_index'
  end

  def down
    remove_index_if_exists Spree::User.table_name, :seller_rank
    remove_column_if_exists Spree::User.table_name, :seller_rank
  end
end
