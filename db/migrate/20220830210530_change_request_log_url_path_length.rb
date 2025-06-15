class ChangeRequestLogUrlPathLength < ActiveRecord::Migration[6.0]
  def change
    change_column RequestLog.table_name.to_sym, :url_path, :string, limit: 400
  end
end
