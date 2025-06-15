module Spree
  class AdoptionPrice < Spree::Base
    self.table_name = 'spree_adoption_prices'

    RELEASE_VERSION = "1.0.2"

    belongs_to :variant_adoption, class_name:'Spree::VariantAdoption'

    scope :within_boundaries, -> { where('boundary_difference=0.0') }

    delegate :variant, :product, to: :variant_adoption

    before_update :check_changes

    #################################
    # Copied from Spree::Price

    include VatPriceCalculation

    MAXIMUM_AMOUNT = BigDecimal('99_999_999.99')

    before_validation :ensure_currency

    validates :amount, allow_nil: true, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: MAXIMUM_AMOUNT
    }

    extend DisplayMoney
    money_methods :amount, :price

    self.whitelisted_ransackable_attributes = ['amount']

    def money
      Spree::Money.new(amount || 0, currency: currency)
    end

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    alias_attribute :price, :amount

    def price_including_vat_for(price_options)
      # variant.tax_category would call product.tax_category. Avoiding this to optimize
      # options = price_options.merge(tax_category: variant.tax_category)
      gross_amount(price, price_options)
    end

    def display_price_including_vat_for(price_options)
      Spree::Money.new(price_including_vat_for(price_options), currency: currency)
    end

    private

    def ensure_currency
      self.currency ||= Spree::Config[:currency] if self.currency.blank?
    end

    def check_changes
      if amount_changed? && variant_adoption.user&.phantom_seller? && !variant_adoption.variant.product.is_price_within_range?(amount)
        new_amount = amount
        self.amount = amount_was # revert amount change        
        begin
          raise Exception.new("Attempt to change price of #{variant_adoption.id} by #{variant_adoption.user&.login} (#{variant_adoption.user_id}) to #{new_amount} using RELEASE_VERSION #{::Spree::AdoptionPrice::RELEASE_VERSION}")
        rescue Exception => e
          ::UserReport.save_user_report(self, comment: e.message + "\n" + e.backtrace.join("\n") )
        end
      end
    end

  end
end