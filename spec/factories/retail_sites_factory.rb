FactoryBot.define do
  
  ###########################################
  # Retail::Store

  factory :retail_store, class: Retail::Store do

    factory :basic_retail_store, aliases: [:rainbow_store, :clothing_retail_store, :ioffer_store] do
      name { 'Rainbow Clothes' }
      retail_site_id { find_or_create(:ioffer, :name).id  }
      store_url { 'https://www.ioffer.com/stores/rainbow-clothing' }
    end


    factory :aliexpress_store, aliases: [:rg_digital_store] do
      name { 'RG Digital Store' }
      retail_site_id { find_or_create(:aliexpress, :name).id  }
      store_url { 'https://www.aliexpress.com/store/5614323?spm=a2g0o.detail.100005.1.3b716ec8B0TpAX' }
    end
  end

  ###########################################
  # Retail::Site

  factory :retail_site, class: Retail::Site do
    factory :ioffer do
      name { 'ioffer' }
      domain { 'ioffer.com' }
      initial_url { '/' }
      site_scraper { 'Scraper::Ioffer' }
    end

    factory :aliexpress do
      name { 'aliexpress' }
      domain { 'aliexpress.com' }
      initial_url { '/' }
      site_scraper { 'Scraper::Aliexpress' }
    end
  end
end