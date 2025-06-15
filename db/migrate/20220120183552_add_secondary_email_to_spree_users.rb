class AddSecondaryEmailToSpreeUsers < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::User.table_name, :secondary_email, :string, limit: 255
  end

  def down
    remove_column_if_exists Spree::User.table_name, :secondary_email
  end
end
