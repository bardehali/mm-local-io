class AddNewIofferPaymentMethods < ActiveRecord::Migration[6.0]
  def change
    %w(xoom xendpay remitly).each do|name|
      Ioffer::PaymentMethod.find_or_create_by(name: name) do|p|
        p.display_name = name.titleize
      end
    end

    puts 'Create connections to Ioffer::UserPayment of same-name payment_method -------'
    Spree::StorePaymentMethod.includes(:payment_method, store:[:user]).all.each do|store_pm|
      begin
         store_pm.ensure_same_ioffer_user_payment_method!
      rescue Exception => e
        puts "** Error: #{e.message} for store of #{store_pm.store&.user&.to_s}"
      end
    end
  end
end
