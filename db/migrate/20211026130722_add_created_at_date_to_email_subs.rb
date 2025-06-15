class AddCreatedAtDateToEmailSubs < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :email_subscriptions, :created_at_date, :string, length: 36
    add_index_unless_exists :email_subscriptions, [:created_at, :created_at_date]
    Ioffer::EmailSubscription.all.update_all("created_at_date=DATE_FORMAT(created_at,'%Y-%m-%d %H')")
  end

  def down
    remove_index_if_exists :email_subscriptions, [:created_at, :created_at_date]
    remove_column_if_exists :email_subscriptions, :created_at_date
  end
end
