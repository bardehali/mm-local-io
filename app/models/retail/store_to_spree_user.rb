module Retail
  class StoreToSpreeUser < ::ApplicationRecord

    self.table_name = 'retail_stores_spree_users'

    belongs_to :retail_store, class_name: 'Retail::Store'
    belongs_to :retail_site, class_name: 'Retail::Site'
    belongs_to :spree_user, foreign_key: 'spree_user_id', class_name: 'Spree::User'

    before_create :set_other_attributes

    private

    def set_other_attributes
      self.retail_site_id ||= retail_store.retail_site_id
    end
  end
end