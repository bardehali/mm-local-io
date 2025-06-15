class AddUserIdToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column_unless_exists :users, :user_id, :integer
    add_index_unless_exists :users, :user_id

    puts "| connecting (#{Ioffer::User.count}) Ioffer::User to Spree::User via user_id"
    count_of_invalid_username = 0
    Ioffer::User.all.each do|ioffer_user|
      if ioffer_user.username =~ /\A\d+/
        count_of_invalid_username += 1
      else
        ioffer_user.convert_to_spree_user!
      end
    end
  end
end