module Spree::TaxCategoryDecorator

  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def default
      Rails.cache.fetch 'tax_category.default', expires_in: 1.day do
        find_by(is_default: true) || self.create(name: 'Default', is_default: true)
      end
    end
  end
end

::Spree::TaxCategory.prepend Spree::TaxCategoryDecorator if ::Spree::TaxCategory.included_modules.exclude?(Spree::TaxCategoryDecorator)