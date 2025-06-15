module Spree
  class EmailCampaign < ApplicationRecord
    self.table_name = 'email_campaigns'
    
    belongs_to :user_list
    has_many :email_campaign_deliveries
    has_many :deliveries, class_name:'Spree::EmailCampaignDelivery'

    after_create :populate_deliveries

    # Called in after_create and can be called manually later, 
    # as it does find_or_create_by(user_id, email)
    def populate_deliveries
      user_list.users.each do|u|
        bounces_count = EmailBounce.where(email: u.email).count
        if bounces_count == 0
          self.email_campaign_deliveries.find_or_create_by(user_id: u.id, email: u.email)
        end
      end
    end
  end
end