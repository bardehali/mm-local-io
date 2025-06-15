class Ioffer::EmailSubscription < ApplicationRecord

  EMAIL_REGEXP = /\A([^@\.]|[^@\.]([^@\s]*)[^@\.])@([^@\s]+\.)+[^@\s]+\z/i

  validates :email, presence: true, format: EMAIL_REGEXP

  before_validation :normalize_attributes

  private

  def normalize_attributes
    self.email.strip! if email
    self.created_at_date = (created_at || Time.now).strftime('%Y-%m-%d')
  end
end