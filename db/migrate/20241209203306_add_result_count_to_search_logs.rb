class AddResultCountToSearchLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :search_logs, :result_count, :integer, default: 0, null: false
  end
end
