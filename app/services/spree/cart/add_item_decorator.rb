module Spree::Cart::AddItemDecorator
  
  def self.prepended(base)
    base.extend MoreClassMethods
  end

  module MoreClassMethods
    ##
    # If different variant of same option values than already in cart, remove the LineItem for @variant.
    # If buyer_user_id is nil, would mean it's guest, so @order_token would be used to query
    # @yield [Spree:LineItem] when found a LineItem that has variant with same set of option values (excluding blank)
    # @return [Array of Integer, variant IDs of those LineItem deleted]
    def clean_line_items_similar_to(buyer_user_id, order_token, variant, &block)
      deleted_variant_ids = []
      key = variant.option_values.collect(&:id).sort
      Spree::Variant.logger.debug "clean_line_items_of #{variant.id}, w/ option values #{key}"
      
      qcond = buyer_user_id ? { user_id: buyer_user_id } : { token: order_token }
      Spree::Order.incomplete.where(qcond).includes(line_items: { variant: :option_value_variants }).each do|order|
        order.line_items.each do|line_item|
          next if line_item.variant.nil?
          this_key = line_item.variant.option_value_variants.collect(&:option_value_id).sort
          if key.present? && key == this_key 
            yield line_item if block_given?
            if variant.id != line_item.variant_id
              Spree::Variant.logger.debug " - deleting variant #{line_item.variant_id} w/ option values #{this_key}" 
              deleted_variant_ids << line_item.variant_id
              line_item.destroy
            end
          end
        end
      end # each order
      deleted_variant_ids
    end
  end
end

Spree::Cart::AddItem.prepend(Spree::Cart::AddItemDecorator) if Spree::Cart::AddItem.included_modules.exclude?(Spree::Cart::AddItemDecorator)