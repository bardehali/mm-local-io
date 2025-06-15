class AddStateToRequestLogs < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :request_logs, :state, :string, limit: 64
    add_column_unless_exists :request_logs, :state_iso_code, :string, limit: 32
    add_column_unless_exists :request_logs, :zip_code, :string, limit: 64
    add_column_unless_exists :request_logs, :latitude, :float
    add_column_unless_exists :request_logs, :longitude, :float

    query = RequestLog.where(group_name:'sign_in').where('ip is not null')
    puts "==================================\nThere r #{query.count} to re-fetch"
    index = 0
    query.all.each do|log|
      puts "#{index} -------------------" if index % 100 == 99
      log.set_more_data
      log.save
      index += 1
    end
  end

  def down
    [:state, :state_iso_code, :zip_code, :latitude, :longitude].each do|col|
      remove_column_if_exists :request_logs, col
    end
  end
end
