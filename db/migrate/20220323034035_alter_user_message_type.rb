class AlterUserMessageType < ActiveRecord::Migration[6.0]
  def change
    begin
      User::Message.connection.execute("ALTER TABLE user_messages ALTER type SET DEFAULT 'User::Message'")
    rescue Exception => dbe
      puts "** Database execute error: #{dbe.message}"
    end
  end
end
