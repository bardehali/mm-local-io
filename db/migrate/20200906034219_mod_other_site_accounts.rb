class ModOtherSiteAccounts < ActiveRecord::Migration[6.0]
  def change
    change_column :other_site_accounts, :site_name, :string, limit: 64, null: true
    change_column :other_site_accounts, :account_id, :string, limit: 256
  end
end
