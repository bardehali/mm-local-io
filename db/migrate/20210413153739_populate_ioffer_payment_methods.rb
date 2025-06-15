class PopulateIofferPaymentMethods < ActiveRecord::Migration[6.0]
  def change
    [ {"name":"paypal","display_name":"PayPal","position":1,"is_user_created":false},
      {"name":"alipay","display_name":"Alipay","position":2,"is_user_created":false},
      {"name":"wechat","display_name":"WeChat","position":3,"is_user_created":false},
      {"name":"worldpay","display_name":"WorldPay","position":4,"is_user_created":false},
      {"name":"ipaylinks","display_name":"iPayLinks","position":5,"is_user_created":false},
      {"name":"transferwise","display_name":"TransferWise","position":6,"is_user_created":false},
      {"name":"western_union","display_name":"Western Union","position":7,"is_user_created":false},
      {"name":"bitcoin","display_name":"Bitcoin","position":8,"is_user_created":false},
      {"name":"paysend","display_name":"PaySend","position":9,"is_user_created":false},
      {"name":"scoinpay","display_name":"SCoinPay","position":10,"is_user_created":false},
      {"name":"ping","display_name":"Ping++","position":11,"is_user_created":false},
      {"name":"silver_coins","display_name":"Silver Coins","position":13,"is_user_created":true} 
    ].each do|ar|
      puts ar
      this_pm = Ioffer::PaymentMethod.find_or_initialize_by(name: ar[:name] ) do|pm|
        pm.attributes = ar
      end
      this_pm.position = ar['position']
      puts '%20s | new? %5s' % [ ar[:name], this_pm.new_record?]
      # this_pm.save
    end
  end
end
