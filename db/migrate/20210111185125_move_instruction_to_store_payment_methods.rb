class MoveInstructionToStorePaymentMethods < ActiveRecord::Migration[6.0]
  def change

    add_column_unless_exists :spree_store_payment_methods, :instruction, :text
    add_index_unless_exists :spree_store_payment_methods, :store_id, name: 'store_pm_inst_store_id'
    add_index_unless_exists :spree_store_payment_methods, [:store_id, :payment_method_id], name: 'store_pm_inst_store_id_pm_id'

    puts "Total %d PaymentMethodInstruction" % [Spree::PaymentMethodInstruction.count]
    Spree::PaymentMethodInstruction.all.each do|pmi|
      next if pmi.store_id.nil?
      store_pm = Spree::StorePaymentMethod.find_or_initialize_by(store_id: pmi.store_id, 
        payment_method_id: pmi.payment_method_id)
      store_pm.instruction = pmi.instruction
      store_pm.save
    end

    drop_table_if_exists :spree_payment_method_instructions
  end
end
