class Ioffer::PaymentMethod < ApplicationRecord
  default_scope -> { order('position asc') }

  scope :not_created_by_users, -> { where('is_user_created = false') }
  scope :created_by_users, -> { where('is_user_created = true') }

  has_many :user_payment_methods, class_name:'Ioffer::UserPaymentMethod', dependent: :delete_all

  before_create :set_other_attributes

  def self.populate
    list = YAML::load_file( File.join(Rails.root, 'db/payment_methods.yml') )
    list.each_with_index do|pair, index|
      pm = PaymentMethod.find_or_initialize_by(is_user_created: false, name: pair[0] ) do|r|
        r.display_name = pair[1]
      end
      pm.is_user_created = false
      pm.position = index + 1
      pm.save
    end
  end

  ##
  # Find or create Spree::PaymentMethod w/ same name.
  # @return [Collection of Spree::PaymentMethod]
  def self.populate_spree_payment_methods_accordingly(&block)
    self.all.collect do|pm|
      spree_pm = pm.same_spree_payment_method
      yield spree_pm if block_given?
    end
  end

  #########################
  # Instance methods

  ##
  # Same ioffer payment method (old seller selected payments).
  # @return [Spree::PaymentMethod]
  def same_spree_payment_method(create_if_needed = true)
    spree_pm = Spree::PaymentMethod.find_or_initialize_by(name: name) do|pm|
      pm.description = display_name || pm.name.titleize
    end
    spree_pm.save if spree_pm.new_record? && create_if_needed
    spree_pm
  end

  protected

  ##
  # Normalize the name and calculate position
  def set_other_attributes
    self.position = ( Ioffer::PaymentMethod.select('max(position) as position').last.try(:position) || 0 ) + 1
    logger.info "| position after #{self.position}"
    if display_name.present?
      self.display_name.strip!
      self.name = display_name.gsub(/(\s+)/, '_').downcase if name.blank?
    end
    self.name = name.to_underscore_id if name
  end
end