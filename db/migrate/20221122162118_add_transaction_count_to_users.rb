class AddTransactionCountToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists ::Spree::User.table_name, :count_of_transactions, :integer, default: 0
    add_index_unless_exists ::Spree::User.table_name, [:deleted_at, :count_of_transactions]

    # instruction is text, which needs fulltext
    [:account_parameters].each do|f|
      add_index_unless_exists ::Spree::StorePaymentMethod.table_name, f
    end
    begin
      # no db migration syntax to add fulltext index
      ActiveRecord::Base.connection.execute "ALTER TABLE #{Spree::StorePaymentMethod.table_name} ADD FULLTEXT (instruction)"
    rescue Exception => db_e
      puts "** Problem in adding FULLTEXT index of instruction"
    end
  end

  def down
    remove_index_if_exists ::Spree::User.table_name, [:deleted_at, :count_of_transactions]
    remove_column_if_exists ::Spree::User.table_name, :count_of_transactions

    [:account_parameters].each do|f|
      remove_index_if_exists ::Spree::StorePaymentMethod.table_name, f
    end
  end
end
