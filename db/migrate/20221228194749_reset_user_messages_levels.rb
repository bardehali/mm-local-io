class ResetUserMessagesLevels < ActiveRecord::Migration[6.0]
  def change
    # All order messages
    ::User::Message.where("type LIKE 'User::Order%'").in_batches do|subq|
      subq.each do|m|
        m.update_columns(level: m.overriding_level || m.class.level)
      end
    end
  end
end
