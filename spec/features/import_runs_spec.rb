require 'rails_helper'

RSpec.describe Scraper::ImportRun, type: :feature do
  let (:aliexpress_search_url) { 'https://www.aliexpress.com/wholesale?SearchText=kaws&d=y&origin=n&catId=0&initiative_id=SB_20200528062125' }

  it 'Create Import of Aliexpress Search' do
    retail_store = find_or_create(:aliexpress_store, :name)
    expect(retail_store).not_to be_nil
    expect(retail_store.retail_site).not_to be_nil

    import_run = Scraper::ImportRun.create(initial_url: aliexpress_search_url)
    expect(import_run).not_to be_nil
    expect(import_run.retail_site_id).to eq (retail_store.retail_site_id)
    
  end
end