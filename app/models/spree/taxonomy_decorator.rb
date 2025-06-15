module Spree::TaxonomyDecorator
  def self.prepended(base)
    base.attr_accessor :token
    base.extend ClassMethods
  end
  
  module ClassMethods

    def categories_taxonomy
      @@categories_taxonomy ||= ::Spree::CategoryTaxon.find_or_create_categories_taxonomy
    end
  end
end

::Spree::Taxonomy.prepend Spree::TaxonomyDecorator if ::Spree::Taxonomy.included_modules.exclude?(Spree::TaxonomyDecorator)