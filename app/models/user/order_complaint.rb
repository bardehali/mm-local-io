
##
# Attribute references used to identify reason and subject,
# instead one subclass for each reason.
module User
  class OrderComplaint < OrderMessage
    def self.level
      1000
    end

    def self.list_of_references
      ['order_no_seller_response', 'order_cannot_pay_seller', 'order_already_paid', 'order_seller_does_not_accept', 
        'order_seller_changed_price', 'order_need_tracking_number',
        'order_item_not_received', 'order_wrong_item', 'order_long_shipping_time', 'order_other_reason'
      ]
    end

    def self.payment_complaint_references
      ['order_cannot_pay_seller', 'order_seller_does_not_accept', 'order_seller_changed_price', 'order_other_reason']
    end

    ##
    # For select_tag options: [type_in_words, type_id]
    # @variables [Hash] those that pass onto I18n.t
    def self.buyer_reasons(variables = {})
      payment_method = variables[:payment_method]
      payment_method = 'PayPal' if payment_method.blank?
      ( ['order_please_select_reason'] + list_of_references ).collect do|reason_id|
        [ I18n.t("message.#{reason_id}.subject", variables.merge(payment_method: payment_method)), 
          reason_id.to_s == 'order_please_select_reason' ? '' : reason_id ]
      end
    end

    def type_id
      references.present? ? references : 'order_other_reason'
    end

    def subject_evaluated
      I18n.t("message.#{type_id}.subject",  { payment_method: payment_method_name })
    end

    ##
    # Override
    def instruction
      if references == 'order_seller_changed_price' && amount.to_f > 0 && record
        I18n.t('message.from_to', from: ('$%.2f' % [record&.total.to_f]), to: ('$%.2f' % [amount] ) )
      else
        super
      end
    end

    def path
      original = super
      original.present? ? original : admin_order_path(order) 
    end

    def show_only_to_recipient?
      ['order_need_tracking_number'].include?(references)
    end

    def recipient_must_respond?
      ['order_no_seller_response', 'order_seller_changed_price'].exclude?(references)
    end

    def overriding_level
      if record&.latest_tracking_number.blank?
        self.class.level + 100
      end
    end


    protected

    def set_defaults
      super
      self.references = 'order_other_reason' if references.blank?
    end

  end
end