class CreateSpreeStorePaymentMethods < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_store_payment_methods do |t|
      t.integer :store_id
      t.integer :payment_method_id
      t.string :account_parameters
      t.string :account_label

      t.timestamps
    end
  end
end
