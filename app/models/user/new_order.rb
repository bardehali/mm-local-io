module User
  class NewOrder < OrderMessage

    alias_method :order, :record

    ##
    # Distinguish initial and follow-up messages
    def self.level
      INITIAL_ORDER_LEVEL
    end

    def initial_show_only?
      true
    end
    
    ##
    # Shows every line item in the cart/order separated w/ newline.
    def subject_in_html
      if record.is_a?(Spree::Order) # who knows, might be bad data.
        s = ''
        record.line_items.includes(:product).each_with_index do|line_item, index|
          s += "</br>" if index > 0
          s += I18n.t("message.#{type_id}.subject_with_product_details", 
            { quantity: line_item.quantity, 
              product_name: "<a href='#{product_path(id: line_item.product_id)}' target='_blank'>#{line_item.product.name}</a>",
              price: line_item.display_total.to_html, 
              payment_method: 
                index == 0 ? ' ' + payment_method_name : ''
            } )
        end
        s
      else
        super
      end
    end

  end
end