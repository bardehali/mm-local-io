class SetSampleStoreInfo < ActiveRecord::Migration[6.0]
  def change
    if (sample_store = Spree::Store.where(default: true).first )
      sample_store.update(name: 'iOffer Marketplace', url:'ioffer.com', mail_from_address:'cs@ioffer.com', code:'ioffer-store')
    end
  end
end
