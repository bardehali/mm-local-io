class AddTestUserRole < ActiveRecord::Migration[6.0]
  def change
    test_user_role = Spree::Role.find_or_create_by(name: 'test_user')
    test_user_role.update(level:  500)

    pending_seller_role = Spree::Role.find_or_create_by(name: 'pending_seller')
    pending_seller_role.update(level: 400)

    Spree::User.where(username: %w(ken bill NeiliOffer rayl000 roypli neil222222 tifanshop caiusgum2020) ).each do|user|
      user.role_users.find_or_create_by(role_id: test_user_role.id)
    end
  end
end
