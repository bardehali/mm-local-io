# This migration comes from spree (originally 20210114220232)
class MigrateDataPaymentMethodsStores < ActiveRecord::Migration[5.2]
  def up
    Spree::PaymentMethod.where('created_at < ?', Time.local(2021,4,1) ).each do |payment_method|
      next if payment_method.store_payment_methods.count > 0 || Rails.env.staging? || Rails.env.production?

      if payment_method[:store_id].present?
        payment_method.store_payment_methods.create_or_create_by( store_id: payment_method[:store_id] )
      else
        Spree::Store.ids.each do|store_id|
          payment_method.store_payment_methods.find_or_create_by( store_id: store_id )
        end
      end

      payment_method.save
    end
  end
end
