class FixIofferUserRatingAndCountry < ActiveRecord::Migration[6.0]
  def change
    puts "Recalculating rating based on transactions_count"
    Ioffer::User.where('transactions_count > 0').all.each{|u| u.update(rating: (u.transactions_count - u.negative).to_f / u.transactions_count * 100.0 ) }.class

    puts "Migrating China to spree_users.country"
    Ioffer::User.where("location='zh-CN'").each{|iu| user = iu.spree_user; next if user.nil?; user.update(country: 'China') if user.country.blank? }.class

  end
end
