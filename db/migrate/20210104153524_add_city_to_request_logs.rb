class AddCityToRequestLogs < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :request_logs, :city, :string, limit: 128

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
    remove_column_if_exists :request_logs, :city
  end
end
