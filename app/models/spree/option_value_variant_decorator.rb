module Spree::OptionValueVariantDecorator
  def self.prepended(base)

    # Need to refer to even deleted variant
    with_options inverse_of: :option_value_variants do
      base.belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    end

    base.has_one :product, through: :variant

  end

  ##
  # Check back if the set option_value is within the set of product.option_types
  def validate_according_to_product
    if product&.id && option_value
      product_ot_ids = product.product_option_types.collect(&:option_type_id)
      unless product_ot_ids.include?(option_value.option_type_id)
        self.errors.add(:option_value_id, "This option value is not within the product's set of option types")
      end
    end
  end
end

Spree::OptionValueVariant.prepend(Spree::OptionValueVariantDecorator) if Spree::OptionValueVariant.included_modules.exclude?(Spree::OptionValueVariantDecorator)