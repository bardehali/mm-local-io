module Spree::StoreDecorator
  def self.prepended(base)
    base.before_validation :normalize_attributes

    base.has_many :store_payment_methods, dependent: :delete_all

    base.has_many :payment_methods, through: :store_payment_methods, class_name:'Spree::PaymentMethod'
    base.belongs_to :user, class_name:'Spree::User'
    base.has_one :retail_store_to_user, class_name:'Retail::StoreToSpreeUser', through: :user
    base.has_one :retail_store, class_name:'Retail::Store', through: :retail_store_to_user
    base.has_one :retail_site, class_name:'Retail::Site', through: :retail_store

    base.whitelisted_ransackable_associations = ['store_payment_methods']
  
    base.extend(ClassMethods)
  end

  module ClassMethods
    def admin_store
      Spree::User.fetch_admin.fetch_store
    end

    ##
    # Until we have multiple domains, this would optimize little.
    def current(domain)
      default
    end
  end

  def default_currency
    self.attributes['default_currency'] || 'USD'
  end

  def to_s
    h = attributes.slice('id', 'name', 'user')
    h.as_json.to_s
  end

  def has_payment_method?(payment_method_id)
    store_payment_methods.collect(&:payment_method_id).include?(payment_method_id)
  end

  def has_paypal?
    has_payment_method?(Spree::PaymentMethod.paypal&.id)
  end

  ##
  # @return [Hash or nil]
  def account_parameters_of(payment_method_id)
    return nil if store_payment_methods.blank?
    store_payment_methods.to_a.find{|spm| spm.payment_method_id == payment_method_id }&.account_hash
  end

  def paypal_store_payment_method
    store_payment_methods.to_a.find{|spm| spm.payment_method_id == Spree::PaymentMethod.paypal.id }
  end

  private

  def normalize_attributes
    self.default_currency ||= 'USD'
  end
end

::Spree::Store.prepend Spree::StoreDecorator if ::Spree::Store.included_modules.exclude?(Spree::StoreDecorator)