class AddLastEmailAtToSpreeUsers < ActiveRecord::Migration[6.0]
  def change
    add_column_unless_exists :spree_users, :last_email_at, :datetime
    add_index_unless_exists :spree_users, :last_email_at

    puts 'Copy over last_email_at from ioffer users'
    query = Ioffer::User.where("last_email_at is not null")
    puts "Total to copy: #{query.count}"
    query.each do|ioffer_user|
      begin
        user = ioffer_user.convert_to_spree_user!
        user.update(last_email_at: ioffer_user.try(:last_email_at)) if user
      rescue Exception => db_e
        puts "** Problem copying over email of Ioffer::User(#{ioffer_user.id})"
      end
    end
  end
end
