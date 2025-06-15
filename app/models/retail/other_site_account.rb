class Retail::OtherSiteAccount < ApplicationRecord
  self.table_name = 'other_site_accounts'

  belongs_to :user, class_name: 'Spree::User'

  validates_presence_of :user_id, :account_id
  before_save :check_attributes

  protected 

  def check_attributes
    
  end
end