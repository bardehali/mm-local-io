FactoryBot.define do
  factory :role, class: Spree::Role do
    factory :admin_role do
      name { 'admin' }
      level { 500 }
    end

    factory :supplier_role do
      name { 'supplier_admin' }
      level { 400 }
    end

    factory :approved_seller_role do
      name { 'approved_seller' }
      level { 300 }
    end
    
    factory :pending_seller_role do
      name { 'pending_seller' }
      level { 200 }
    end

    factory :phantom_seller_role do
      name { 'phantom_seller' }
      level { 100 }
    end

    factory :quarantined_user_role do
      name { 'quarantined_user' }
      level { 100 }
    end
  end

  #####################
  # User

  factory :user, class: Spree::User do

    trait :real_ip do
      current_sign_in_ip { '98.110.194.34' }
    end
    trait :china_email do 
      email { 'marketshopper@163.com' }
    end
    trait :ip_usa do
      current_sign_in_ip { '210.138.184.59' }
    end
    trait :ip_japan do
      current_sign_in_ip { '210.138.184.59' }
    end
    trait :ip_france do
      current_sign_in_ip { '212.83.162.129' }
    end
    

    factory :admin_user do
      email { 'admin@shoppn.com' }
      username { 'admin' }
      display_name { 'Site Manager' }
      spree_roles { [Spree::Role.find_or_create_by!(name: 'admin') ] }
    end

    factory :basic_user, aliases: [:viewer, :buyer, :boy_user] do
      email { 'buyer01@gmail.com' }
      username { 'bison' }
      display_name { 'Bison' }
    end

    factory :another_user, aliases: [:viewer_2, :buyer_2, :boy_user_2] do
      email { 'buyer02@gmail.com' }
      username { 'connor' }
      display_name { 'Connor' }
    end

    factory :buyer_3, aliases: [:viewer_3, :boy_user_3, :girl_user] do
      email { 'buyer03@gmail.com' }
      username { 'sarah' }
      display_name { 'Sarah' }
    end

    factory :seller, aliases: [:basic_seller, :pending_seller_user] do
      email { 'seller01@gmail.com' }
      username { 'sally' }
      display_name { 'Sally' }
      spree_roles { [Spree::Role.find_or_create_by(name: 'pending_seller'){|r| r.level = 150; } ] }
    end

    factory :seller_2, aliases: [:another_seller] do
      email { 'seller02@gmail.com' }
      username { 'sammy' }
      display_name { 'Sammy' }
      spree_roles { [Spree::Role.find_or_create_by(name: 'pending_seller'){|r| r.level = 100; } ] }
    end

    factory :seller_3, aliases: [:approved_seller] do
      email { 'seller03@gmail.com' }
      username { 'sarah' }
      display_name { 'Sarah' }
      spree_roles { [Spree::Role.find_or_create_by(name: 'approved_seller'){|r| r.level = 200; } ] }
    end

    factory :some_phantom_user, aliases: [:phantom_seller] do
      email { 'phantomseller01@gmail.com' }
      username { 'philo' }
      display_name { 'Philo' }
      spree_roles { [Spree::Role.find_or_create_by(name: 'phantom_seller'){|r| r.level = 100; } ] }
    end

    factory :some_quarantined_user, aliases: [:quarantined_user] do
      email { 'quarantineduser@gmail.com' }
      username { 'quad' }
      display_name { 'Quadro' }
      after(:create) do|u|
        u.soft_delete!
      end
    end
  end

  factory :address, class: Spree::Address do
    factory :basic_address, aliases: [:boston, :usa_address, :business_address] do
      firstname { 'Mary' }
      lastname { 'Sanders' }
      address1 { '100 Washington ST' }
      city { 'Boston' }
      zipcode { '02161' }
      phone { '6177208112' }
      state_name { 'MA' }
      company { 'MS Merchandise' }
      country_id { find_or_create(:country_usa, :iso).id }
      state_id { find_or_create(:ma_state, :name).id  }
    end
  end

  factory :country, class: Spree::Country do
    factory :country_usa, aliases: [:basic_country] do
      iso_name { 'UNITED STATES' }
      iso { 'US' }
      iso3 { 'USA' }
      name { 'United States' }
      numcode { 840 }
      states_required { true }
    end
  end

  factory :state, class: Spree::State do
    factory :state_ma, aliases: [:ma_state] do
      name { 'Massachusetts' }
      abbr { 'MA' }
      country_id { find_or_create(:country_usa, :iso).id }
    end

    factory :state_ca, aliases: [:ca_state] do
      name { 'California' }
      abbr { 'CA' }
      country_id { find_or_create(:country_usa, :iso).id }
    end
  end
end