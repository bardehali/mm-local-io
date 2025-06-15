class CreatePaymentMethodInstructions < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_payment_method_instructions do |t|
      t.integer :user_id, null: false
      t.integer :store_id, null: false
      t.integer :payment_method_id, null: false
      t.text    :instruction
      
      t.index :store_id, name: 'pm_inst_store_id'
      t.index [:store_id, :payment_method_id], name: 'pm_inst_store_id_pm_id'
    end
  end

  def down
    drop_table_if_exists :spree_payment_method_instructions
  end
end
