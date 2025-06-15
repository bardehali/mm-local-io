class EnsureMoreSpreePaymentMethods < ActiveRecord::Migration[6.0]
  def change
    special_description = {'ping' => 'Ping++', 'transferwise' => 'TransferWise', 
      'xendpay' => 'XendPay', 'ipaylinks' => 'iPayLinks', 'western_union' => 'Western Union', 
      'wechat' => 'WeChat'}
    %w(paypal transferwise remitly xendpay worldpay ipaylinks western_union bitcoin paysend scoinpay ping alipay wechat xoom).each_with_index do|pm_name, index|
      pm = Spree::PaymentMethod.find_or_create_by(name: pm_name)
      pm.update(description: special_description[pm_name] || pm_name.titleize, 
        position: index + 1, available_to_users: true, available_to_admin: true, display_on:'Both')
    end

    index = 0
    Ioffer::User.includes(:payment_methods).find_in_batches do|batch|
      batch.each do|u|
        index += 1
        begin
          u.convert_payment_methods!
        rescue Exception => e
          puts "** problem converting iOffer user #{u.id}: #{e.message}"
        end
      end
      puts '%5d ------------------------' % [index]
    end
  end
end
