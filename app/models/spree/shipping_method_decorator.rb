module Spree::ShippingMethodDecorator
  def self.prepended(base)
    base.extend ClassMethods
    base.before_create :ensure_shipping_rates
  end

  module ClassMethods
    def populate_with_common_shipping_methods
      shipping_methods = []
      this_sm = self.find_or_create_by(name: 'USPS') do|sm|
        sm.display_on = 'both'
        sm.admin_name = 'usps'
        sm.code = 'us_postal'
      end
      set_common_attributes(this_sm)
      this_sm.save
      shipping_methods << this_sm
      
      this_sm = self.find_or_create_by(name: 'UPS Ground') do|sm|
        sm.display_on = 'both'
        sm.admin_name = 'ups_ground'
        sm.code = 'ups_ground'
      end
      set_common_attributes(this_sm)
      this_sm.save
      shipping_methods << this_sm

      this_sm = self.find_or_create_by(name: 'Fedex') do|sm|
        sm.display_on = 'both'
        sm.admin_name = 'fedex'
        sm.code = 'fedex'
      end
      set_common_attributes(this_sm)
      this_sm.save
      shipping_methods << this_sm

      shipping_methods
    end

    def set_common_attributes(shipping_method)
      shipping_method.available_to_all = true
      shipping_method.available_to_users = true
      shipping_method.tax_category_id = Spree::TaxCategory.find_by(is_default: true)&.id
      shipping_method.calculator = Spree::Calculator.find_or_create_by(calculable_type: 'Spree::ShippingMethod', calculable_id: shipping_method.id) do|c|
          c.type = 'Spree::Calculator::Shipping::FlatPercentItemTotal'
          c.preferences = {:flat_percent=>0.0}
        end
      shipping_method.shipping_categories = [Spree::ShippingCategory.default]
    end

    def standard_delivery
      @@standard_delivery ||= Spree::ShippingMethod.find_or_create_by(name: 'Standard Delivery') do|sm|
          sm.display_on = 'both'
          sm.admin_name = 'standard'
          sm.code = 'standard'
        end
    end
  end

  ##
  # Create associated shipping_categories and calculator if necessary
  def ensure_shipping_rates
    self.shipping_categories = [Spree::ShippingCategory.default]
    self.calculator ||= Spree::Calculator::Shipping::FlatPercentItemTotal.new(
        calculable_type:'Spree::ShippingMethod', preferences:{ flat_percent: 0.0 } )
  end
end

Spree::ShippingMethod.prepend(Spree::ShippingMethodDecorator) if Spree::ShippingMethod.included_modules.exclude?(Spree::ShippingMethodDecorator)