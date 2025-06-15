class CreateSpreeUserLists < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :user_lists do |t|
      t.string :name, limit: 100, null: false
      t.integer :parent_user_list_id
      t.timestamps

      t.index :name
      t.index :created_at
    end

    create_table_unless_exists :user_list_users do|t|
      t.string :user_list_id
      t.string :user_id
      t.datetime :created_at
      
      t.index :user_list_id
      t.index [:user_list_id, :user_id]
    end

    create_table_unless_exists :email_campaigns do|t|
      t.string :name, limit: 100, null: false
      t.integer :user_list_id, null: false
      t.timestamps

      t.index :name
      t.index :user_list_id
    end

    create_table_unless_exists :email_campaign_deliveries do|t|
      t.integer :email_campaign_id
      t.integer :user_id
      t.string :email, limit: 120
      t.datetime :delivered_at
      t.integer :trial_count, default: 0
      t.timestamps

      t.index :email_campaign_id
      t.index :user_id
      t.index :email
      t.index :delivered_at
    end

    top_sellers_file = File.join(Rails.root, 'data/top_2000_uncontacted_sellers_filtered.csv')
    if File.exists?(top_sellers_file)
      usernames = []
      emails = []
      CSV.parse(File.read(top_sellers_file), headers: true).each do |csv_row|
        usernames << csv_row['username']
        emails << csv_row['email']
      end
      puts "Importing #{emails.size} to email campaign"

      user_list = Spree::UserList.find_or_create_by(name: 'Top iOffer Sellers Onboarding')
      Spree::User.where(email: emails).each do|user|
        user_list.user_list_users.find_or_create_by(user_id: user.id)
      end

      email_campaign = Spree::EmailCampaign.create(name: 'Advertiser Onboard 2020-11-11', user_list_id: user_list.id)
    end

  end

  def down
    drop_table_if_exists :user_lists
    drop_table_if_exists :user_list_users
    drop_table_if_exists :email_campaigns
    drop_table_if_exists :email_campaign_deliveries
  end
end
