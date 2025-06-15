class AddDhgateToRetailSites < ActiveRecord::Migration[6.0]
  def change
    site = Retail::Site.find_or_create_by(name:'DHGate') do|r|
        r.domain = 'dhgate.com'
        r.initial_url = '/'
        r.site_scraper = 'Scraper::Dhgate'
      end
  end
end
