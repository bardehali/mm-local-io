class Ioffer::Brand < ApplicationRecord
  scope :not_created_by_users, -> { where('is_user_created = false') }
  scope :created_by_users, -> { where('is_user_created = true') }
  default_scope { order('position asc') }

  before_create :set_other_attributes

  def display_name
    presentation
  end

  protected

  ##
  # Normalize the name and calculate position
  def set_other_attributes
    if presentation.present?
      self.presentation.strip!
      self.name = presentation.gsub(/(\s+)/, '_').downcase if name.blank?
    end
  end
end