class ChangeTableCharacterSet < ActiveRecord::Migration[6.0]
  def change
    Retail::Site.connection.tables.each do|table_name|
      Retail::Site.connection.execute("ALTER TABLE #{table_name} CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
    end
  end
end
