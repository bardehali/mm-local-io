FactoryBot.define do
  factory :addresses, class: ::Spree::Address do
    factory :sample_address, aliases: [:sample_us_address, :pending_seller_address] do
      firstname {'Supplier'}
      lastname { 'Inc' }
      address1 {'100 State St'}
      city {'Santa Barbara'}
      zipcode {'93101'}
      phone { '1234567890' }
      state_id { find_or_create(:california_state, :name).id }
      country_id { find_or_create(:united_states, :name).id }
    end

    factory :china_address, aliases: [:full_seller_address] do
      firstname {'Tencent'}
      lastname { 'Inc' }
      address1 {'100 East ST'}
      city {'Guan Zhou'}
      zipcode {'315500'}
      phone { '1234567890' }
      state_id { find_or_create(:guan_dong_state, :name).id }
      country_id { find_or_create(:china, :name).id }
    end
    
  end

  factory :states, class: ::Spree::State do
    factory :california_state, aliases: [:sample_state, :sample_us_state] do
      name {'California'}
      abbr {'CA'}
      country_id { find_or_create(:united_states, :name).id }
    end

    factory :guan_dong_state, aliases: [:china_state] do
      name {'Guan Dong'}
      abbr {'GD'}
      country_id { find_or_create(:china, :name).id }
    end
  end

  # For countries, look into locale_factory.rb

end