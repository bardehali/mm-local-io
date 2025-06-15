module Spree::PriceDecorator

  def self.prepended(base)
    base.include ::Spree::CurrencyToCountry
    base.extend ClassMethods

    base.validates :amount, allow_nil: true, numericality: {
      greater_than: 0.0,
      less_than_or_equal_to: Spree::Price::MAXIMUM_AMOUNT
    }

    base.delegate :user_id, :user, to: :variant

    base.before_save :normalize_country
    base.after_save :update_variant
  end

  module ClassMethods

    def iso_code_to_currency_map
      @@iso_code_to_currency_map ||= Spree::Config.available_currencies.group_by(&:iso_code)
    end

    def default_currency
      Spree::Config[:currency]
    end
  end

  def update_variant

  end

  # @return <Money::Currency> could be nil
  def money_currency
    self.class.iso_code_to_currency_map[ currency.try(:upcase) ].try(:first)
  end

  def has_default_currency?
    currency == self.class.default_currency
  end

  ##
  # If country_iso is still nil, would fetch via currency to country ISO mapping.
  def related_country_isos
    self.class::CURRENCY_TO_COUNTRY_ISO_MAP[ currency.try(:upcase).try(:to_sym) ] || []
  end

  protected

  def normalize_country
    self.country_iso = nil if country_iso.blank?
  end
end

::Spree::Price.prepend ::Spree::PriceDecorator if ::Spree::Price.included_modules.exclude?(::Spree::PriceDecorator)