class AddAsnInfoToRequestLogs < ActiveRecord::Migration[6.0]
  def change
    add_column :request_logs, :asn, :integer, null: false, default: 0
    add_column :request_logs, :asn_org, :string, null: false, default: ''
  end
end
