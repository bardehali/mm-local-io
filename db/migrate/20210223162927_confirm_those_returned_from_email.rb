class ConfirmThoseReturnedFromEmail < ActiveRecord::Migration[6.0]
  def change
    query = RequestLog.where(group_name: 'show_reset_password')
    puts "Based on RequestLog group_name='show_reset_password': #{query.count} records"
    user_ids = Set.new
    query.each do|request_log|
      user_ids << request_log.user_id
      Spree::User.where(id: request_log.user_id).update(confirmed_at: request_log.created_at)
    end

    admin_roles = Spree::Role.where(name: %w(admin supplier_admin) ).all
    Spree::User.where(id: Spree::RoleUser.where(role_id: admin_roles).all.collect(&:user_id) ).each do|u|
      u.update(confirmed_at: u.created_at)
      user_ids << u.id
    end

    #users_query = Spree::User.where("id NOT IN (?)", user_ids )
    #puts "How many users to force to confirm: #{users_query.count}"
    # users_query.each do|user|
    #  raw, enc = Devise.token_generator.generate(user.class, :confirmation_token)
    #  user.update(confirmation_token: raw, confirmed_at: nil)
    # end
  end
end
