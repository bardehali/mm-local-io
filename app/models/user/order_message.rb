module User
  class OrderMessage < Message

    alias_method :order, :record

    before_create :check_user_and_order
    after_create :update_highest_message_level!
    
    def self.level
      ORDER_LEVEL
    end

    def self.group_name
      'orders'
    end

    def self.conditions_from_buyer(order)
      conditions_for_record(order).merge(
        sender_user_id: order.user_id, recipient_user_id: order.seller_user_id
      )
    end

    def self.conditions_from_seller(order)
      conditions_for_record(order).merge(
        sender_user_id: order.seller_user_id, recipient_user_id: order.user_id
      )
    end

    def subject_evaluated
      I18n.t("message.#{type_id}.subject",  { payment_method: payment_method_name, comment: comment })
    end

    def instruction
      instr = I18n.translate("message.#{type_id}.instruction",  { payment_method: payment_method_name })
      instr && instr.match(MISSING_TRANSLATION_REGEXP).nil? ? instr : ''
    end

    def should_highlight?
      # level.to_i >= COMPLAINT_LEVEL
      sender_user_id == record&.user_id
    end

    # Self exclusive method if User::OrderComplaint is still not used
    def overriding_level
      if references.present?
        User::OrderComplaint.list_of_references.include?(references) ? COMPLAINT_LEVEL : nil
      else
        nil
      end
    end
    

    # Common instance methods

    def payment_method_name
      order.latest_payment_method&.description.to_s
    end

    protected

    ##
    # Whether poster is eligible to this order
    def check_user_and_order
      if order
        is_eligible = [order.user_id, order.seller_user_id].include?(sender_user_id) || 
          sender&.admin?
        self.errors.add(:sender_user_id, 'Not elegible to send message in this order')
        if order.user_id == recipient_user_id
          self.last_viewed_at = Time.now
        end
      end
      if (_overriding_level = overriding_level)
        self.level = _overriding_level
      end
    end

    def update_highest_message_level!
      if order
        order.update_highest_message_level!
      end
    end
  end
end