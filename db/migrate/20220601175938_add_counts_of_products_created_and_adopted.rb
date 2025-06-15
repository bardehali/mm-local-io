class AddCountsOfProductsCreatedAndAdopted < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists Spree::User.table_name, :count_of_products_created, :integer, default: 0
    add_column_unless_exists Spree::User.table_name, :count_of_products_adopted, :integer, default: 0

    b = 1
    puts "Total #{Spree::User.sellers.count} sellers"
    Spree::User.includes(:store => :store_payment_methods).sellers.in_batches(of: 100, start: 0) do|relation|
      puts "#{Time.now.to_s(:db)}, batch #{b}"
      relation.each do|u|
        u.calculate_stats!
      end
      unless Rails.env.development? || Rails.env.test?
        sleep rand(5)
      end
      b += 1
    end
  end

  def down
    remove_column_if_exists Spree::User.table_name, :count_of_products_created
    remove_column_if_exists Spree::User.table_name, :count_of_products_adopted
  end
end
