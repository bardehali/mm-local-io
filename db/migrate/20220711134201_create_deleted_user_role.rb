class CreateDeletedUserRole < ActiveRecord::Migration[6.0]
  def up
    role = Spree::Role.find_or_create_by(name: %w(deleted_user quarantined_user) ) do|r|
      r.level = 0
      r.name = 'quarantined_user'
    end
  end

  def down
    Spree::Role.where(name: %w(deleted_user quarantined_user) ).delete_all
  end
end
