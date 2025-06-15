class CleanUpPaymentMethods < ActiveRecord::Migration[6.0]
  def change
    # Names were not cleaned up enough for user-entered names.
    # Look for duplicates of same sanitized name, and reassign user associations, and 
    # then delete them.
    puts 'Cleaning up Ioffer::PaymentMethod'
    ioffer_pm_map = Ioffer::PaymentMethod.all.group_by{|pm| pm.name.to_underscore_id }
    ioffer_pm_map.each_pair do|name, list|
      next if list.size < 2 && !name.blank?
      if name.blank?
        Ioffer::UserPaymentMethod.where(payment_method_id: list.collect(&:id)).delete_all
        list.each(&:destroy)
      else
        first_pm = list.first
        list.each_with_index do|pm, index|
          next if index == 0
          pm.user_payment_methods.update_all(payment_method_id: first_pm.id)
          pm.destroy
        end
      end
    end

    puts 'Cleaning up Spree::PaymentMethod'
    spree_pm_map = Spree::PaymentMethod.all.group_by{|pm| pm.name.to_underscore_id }
    spree_pm_map.each_pair do|name, list|
      next if list.size < 2 && !name.blank?
      if name.blank?
        Spree::StorePaymentMethod.where(payment_method_id: list.collect(&:id)).delete_all
        list.each(&:destroy)
      else
        first_pm = list.first
        list.each_with_index do|pm, index|
          next if index == 0
          Spree::StorePaymentMethod.where(payment_method_id: pm.id).update_all(payment_method_id: first_pm.id)
          pm.destroy
        end
      end
    end
  end
end
