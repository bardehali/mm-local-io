class AddWhatsappToSpreeStores < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_stores, :whatsapp, :string, limit: 20
    add_index :spree_stores, :whatsapp, unique: false
  end
end
