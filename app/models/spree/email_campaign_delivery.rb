module Spree
  class EmailCampaignDelivery < ApplicationRecord
    self.table_name = 'email_campaign_deliveries'
    
    belongs_to :email_campaign
    belongs_to :user, class_name:'Spree::User'

    scope :not_delivered, -> { where('delivered_at is null') }
    scope :delivered, -> { where('delivered_at is not null') }
  end
end