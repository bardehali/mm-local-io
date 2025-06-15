class AddMoreRoles < ActiveRecord::Migration[6.0]
  def change
    add_column_unless_exists :spree_roles, :level, :integer, default: 100
    add_index_unless_exists :spree_roles, :level

    %w(admin supplier_admin approved_seller pending_seller).each_with_index do|role_name, index|
      Spree::Role.find_or_create_by(name: role_name, level: (5 - index) * 100)
    end

    pending_seller_role = Spree::Role.find_by_name 'pending_seller'
    Spree::User.all.each do|u|
      Spree::RoleUser.find_or_create_by(user_id: u.id, role_id: pending_seller_role.id) if u.role_users.count == 0
    end
  end
end
