class UserReport < ApplicationRecord
  include WithOtherRecord

  before_save :set_defaults

  TYPES = ['UserReport::EmailDelivery']
  STATUSES =  %w(new archived reviewed)

  ##
  # General save report based on @record
  def self.save_user_report(record, other_attributes = {})
    create( {
        record_type: record.class.to_s, record_id: record.id, 
        reporter_user_id: Spree::User.fetch_admin.id
      }.reverse_merge( other_attributes || {} )
    )
  end

  protected

  def set_defaults
    self.type = 'UserReport' if type.blank?
    self.status = 'new' if TYPES.exclude?(status)
  end
end