module Spree::ShippingCategoryDecorator

  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def default
      self.last || self.create(name: 'Default')
    end
  end
end

::Spree::ShippingCategory.prepend Spree::ShippingCategoryDecorator if ::Spree::ShippingCategory.included_modules.exclude?(Spree::ShippingCategoryDecorator)