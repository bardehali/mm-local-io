##
# The @name is normalized by downcase, compacted to single spacing, and without prefix "Pay with ".
module Spree::PaymentMethodDecorator

  def self.prepended(base)
    base.extend(ClassMethods)
    base.attr_accessor :store_payment_method

    base.has_many :store_payment_methods
    base.has_many :stores, through: :store_payment_methods

    base.scope :user_selectable, -> { where(available_to_users: true) }

    base.before_save :normalize_attributes

    base.const_set 'AVAILABLE_MINI_ICONS', %w(alipay apple_pay bitcoin ipaylinks paypal paysend ping scoinpay transferwise wechat western_union worldpay)
  end

  def self.inherited(subklass)
    subklass.attr_accessor :store_payment_method
    subklass.before_save :normalize_attributes
  end

  module ClassMethods
    def selectable_for_store(store_id = nil)
      #left_joins(:store_payment_methods).
      # there is an optimized index of (store_id, payment_method_id)
      joins("LEFT OUTER JOIN #{Spree::StorePaymentMethod.table_name} ON #{Spree::StorePaymentMethod.table_name}.payment_method_id = #{Spree::PaymentMethod.table_name}.id AND #{Spree::StorePaymentMethod.table_name}.store_id = #{store_id}").
      where("available_to_users=true#{' OR ' + Spree::StorePaymentMethod.table_name + '.store_id=' + store_id.to_s if store_id}")
    end

    def populate_with_common_payment_methods
      # These r exact name of payment service w/o prefix like "Pay with ".  The before_create call
      # will normalize this description to name in ID format.
      ['PayPal', 'WeChat', 'Apple Pay', 'Google Pay', 'Strip', 'Credit Card, Visa/MasterCard', 
        'Check/Money Order', 'Alipay', 'Western Union', 'TransferWise', 'Remitly', 'Xendpay', 'WorldPay',
        'iPayLinks', 'BitCoin', 'SCoinPay', 'Ping', 'Xoom'].each_with_index do|pm_desc, position|
          pm = payment_method_class(pm_desc).where('name = ? or description = ?', pm_desc, pm_desc).first
          pm ||= payment_method_class(pm_desc).create(name: pm_desc, description: pm_desc)
          pm.active = true
          pm.available_to_users = true
          pm.position = position
          pm.display_on = 'both'
          pm.save
      end
    end

    def payment_method_class(name)
      class_name = if name =~ /credit\s+card/i
        'CreditCard'
      elsif name =~ /check\s*\/\s*Money\s+Order/i
        'CheckMoneyOrder'
      elsif name =~ /^(wechat)\b/i
        'WeChat'
      else
        name.gsub(' ', '').classify
      end
      "Spree::PaymentMethod::#{class_name}".constantize
    rescue NameError
      Spree::PaymentMethod::General
    end

    def cached_payment_method(name)
      Rails.cache.fetch("payment_method_by_name.#{name.to_underscore_id}") do
        Spree::PaymentMethod.find_by(name: name.to_underscore_id)
      end
    end

    def paypal
      cached_payment_method('paypal')
    end

    def wechat
      cached_payment_method('wechat')
    end

    def clear_cache
      all.each do|pm|
        Rails.cache.fetch("payment_method_by_name.#{pm.name.to_underscore_id}")
      end
    end
  end

  ##
  # Depending on payment method type, the attribute name that payer can refer to during payments;
  # for example, credit card needs 'card number' while PayPal simply needs 'Account ID'.
  def account_reference_label
    I18n.t('spree.account_id')
  end

  ##
  # Removes words like 'Pay with' from description
  def display_name
    description.present? ? description.gsub(/(Pay\s+with\s+)/i, '') : name.titleize
  end

  def domain
    "#{name.gsub(/(\s+|\.|_)/,'').downcase}.com"
  end

  def forward_payment_url
    "https://www.#{domain}"
  end

  def payment_source_class
    Spree::PaymentMethod::General
  end

  # Until payment API is integrated, keep this false
  def source_required?
    false
  end

  def paypal?
    id == Spree::PaymentMethod.paypal.id
  end

  ##
  # Same ioffer payment method (old seller selected payments).
  # @return [Ioffer::PaymentMethod]
  def same_ioffer_payment_method
    Ioffer::PaymentMethod.find_by(name: name)
  end

  def normalize_attributes
    self.type ||= 'Spree::PaymentMethod::General'
    self.available_to_users = false if new_record? && store_payment_methods.present?
    self.display_on ||= 'both'
    self.description ||= description.strip_naked.titleize if description
    if name.present?
      self.name = name.compact.downcase
    elsif description
      self.name = description.compact.downcase
    end
    self.name.gsub!(/^(pay\s+with\s+)/i, '')
  end
end

::Spree::PaymentMethod.prepend Spree::PaymentMethodDecorator if ::Spree::PaymentMethod.included_modules.exclude?(Spree::PaymentMethodDecorator)

#Dir.glob( File.join(Rails.root,'app/models/spree/payment_method/*.rb') ).each do|path|
#  if path =~ match(/\/([\w\s]+)\.rb\Z/ )
#    klass = "Spree:PaymentMethod::#{$1}".camelize.constantize
#    klass.prepend Spree::PaymentMethodDecorator if klass.included_modules.exclude?(Spree::PaymentMethodDecorator)
#  end
#end