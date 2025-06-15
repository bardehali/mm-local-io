module Spree::Admin::MoreImagesHelper
    
  def options_for_variant_select(variants, current_value = nil)
    options = []
    excluded_option_type_ids = Spree::OptionType.excluded_ids_from_users
    variants.each do|variant|
      if variant.is_master
        options.insert(0, [ t('all'), variant.id ] )
      else
        options << [variant.sku_and_options_text(nil, excluded_option_type_ids), variant.id]
      end
    end
    options_for_select(options, current_value)
  end
end