module Spree::VariantPresenterDecorator

  def call
    @variants.map do |variant|
      {
        display_price: display_price(variant),
        is_product_available_in_currency: @is_product_available_in_currency,
        backorderable: false, # simply skip for now
        in_stock: true, # for sellers to handle
        images: images(variant),
        option_values: option_values(variant),
      }.merge(
        variant_attributes(variant)
      )
    end
  end

  def display_price(variant)
      adoption = variant.preferred_variant_adoption
      adoption = nil if adoption && adoption.seller_based_sort_rank < variant.seller_based_sort_rank && !variant.user&.phantom_seller?
      adoption ? super(adoption) : super(variant)
  end

  ##
  # Exclude excluded option types
  def option_values(variant)
    values = []
    variant.option_values.each do |option_value|
      next if Spree::OptionType.excluded_ids_from_users.include?(option_value.option_type_id)
      values << {
          id: option_value.id,
          name: option_value.name,
          presentation: option_value.presentation,
        }
    end
    values
  rescue Exception => e
    Spree::User.logger.warn "******* #{e.message}\n#{e.backtrace.join("\n  ")}"
    values
  end
end

Spree::VariantPresenter.prepend(Spree::VariantPresenterDecorator) if Spree::VariantPresenter.included_modules.exclude?(Spree::VariantPresenterDecorator)
