class AddLastOnboardingViewedAt < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :spree_users, :last_passcode_viewed_at, :datetime
  end

  def down
    remove_column_if_exists :spree_users, :last_passcode_viewed_at
  end
end
