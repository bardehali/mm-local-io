class PopulateUserPaymentMethodsCategories < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :user_accepted_payment_methods do|t|
      t.integer :user_id
      t.integer :payment_method_id
      t.index :user_id
    end

    puts "Convert #{Ioffer::User.count} Ioffer users"
    index = 1
    Ioffer::User.all.each do|ioffer_user|
      puts " .. #{index}" if index % 100 == 0
      begin
        ioffer_user.convert!
      rescue Exception => user_e
        puts "** Ioffer::User(#{ioffer_user.id}) convert error: #{user_e.message}"
      end
      index += 1
    end
  end

  def down
    drop_table_if_exists :user_accepted_payment_methods
  end
end
