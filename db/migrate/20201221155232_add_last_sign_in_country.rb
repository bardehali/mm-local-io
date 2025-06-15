class AddLastSignInCountry < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :request_logs, :ip, :string, limit: 64
    add_column_unless_exists :request_logs, :country, :string, limit: 64
  end

  def down
    remove_column_if_exists :request_logs, :ip
    remove_column_if_exists :request_logs, :country
  end
end
