class AddStockXToRetailSites < ActiveRecord::Migration[6.0]
  def change
    site = Retail::Site.find_or_create_by(name: 'StockX') do|r|
      r.domain = 'stockx.com'
      r.initial_url = '/'
      r.user_selectable = true
    end
  end
end
