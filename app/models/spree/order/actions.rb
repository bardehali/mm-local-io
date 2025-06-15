module Spree::Order::Actions
  extend ActiveSupport::Concern

  #########################
  # Actions

  # @create_anyway for case that would need manual call instead of auto after callbacks.
  def create_initial_message!(create_anyway = false)
    msg = User::NewOrder.find_or_initialize_by( User::Message.conditions_for_record(self) )
    msg.sender_user_id ||= user_id
    msg.recipient_user_id ||= seller_user_id
    msg.save
    msg
  end

  def update_highest_message_level!
    self.update_columns(highest_message_level: self.messages.order('level desc').first&.level )
  end

  ##
  # Available public for making up existing orders.
  # @create_anyway for case that would need manual call instead of auto after callbacks.
  def create_message!(create_anyway = false)
    msg = nil
    if state_changed? && complete?
      create_initial_message!
    end
    if payment_state_changed?
      if Spree::Order::PAID_PAYMENT_STATES.include?(payment_state)
        msg = User::OrderPaymentPaid.new( User::OrderMessage.conditions_from_buyer(self) )
      elsif %w(failed).include?(payment_state)
        msg = User::OrderPaymentFailed.new( User::OrderMessage.conditions_from_buyer(self) )
      end
    end
    if approved_at_changed? && approved_at
      msg = User::OrderPaymentConfirmed.new( User::OrderMessage.conditions_from_seller(self) )
    end
    if shipment_state_changed?
      # Possible ready msg
      if shipment_state == 'shipped'
        msg = User::OrderShipped.new( User::OrderMessage.conditions_from_seller(self) )
      end
    end
    if msg
      msg.sender_user_id ||= user_id
      msg.recipient_user_id ||= seller_user_id
      msg.save
    end
    # undefined seller would stay nil
    msg
  end

  # handle_asynchronously :create_message! if Rails.env.production?

  ##
  # Could be state_machine callback, but cannot figure out how to add to existing state_machines definition.
  def check_to_auto_jump
    if state == 'payment'
      if payments.valid.count > 0 # auto jump payment set
        payments.update_all(amount: self.total)
        self.next
      end
    end
  end

  def notify_users
    if state == 'complete'
      send_invoice_to_buyer unless confirmation_delivered
      if seller
        send_order_to_seller
        if Rails.env.production?
          seller.delay(
            queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE, run_at: Spree::User::NOTIFY_EMAIL_DELAY_LENGTH.after ).notify_about_pending_orders
        else
          seller.notify_about_pending_orders
        end
      end
    end
  end

  def send_order_to_seller
    return if seller.nil? || seller.phantom_seller? || (Rails.env.production? && !seller.hp_seller? && !seller.approved_seller?)

    Spree::OrderMailer.with(order: self).new_order_to_seller.deliver

  rescue Exception => e
    UserReport::EmailDelivery.report_delivery_error(self, e, seller_user_id)
  end
  handle_asynchronously :send_order_to_seller, queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE if Rails.env.production?


  def send_invoice_to_buyer(resend = false)
    return true if self.user.nil? || self.user.fake_user? || self.seller.nil? || self.seller.phantom_seller?

    subject_prefix = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
    Spree::OrderMailer.with(order: self, subject_prefix: subject_prefix).invoice_to_buyer.deliver
    self.update_attributes(invoice_last_sent_at: Time.now, confirmation_delivered: true)
  rescue Exception => e
    UserReport::EmailDelivery.report_delivery_error(self, e, user_id)
    raise e
  end
  handle_asynchronously :send_invoice_to_buyer, queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE if Rails.env.production?


  ##
  # For each line item's product, call to update best variant
  def update_products!
    line_items.includes(:product).each do|line_item|
      next if line_item.product.nil?
      should_recal = (line_item.product.transaction_count.to_i % 10 == 9) # every 10 recal
      line_item.product&.update_columns(transaction_count: (should_recal ? line_item.product.calculate_transaction_count : line_item.product.transaction_count.to_i + 1 ) )
    end
  end

  handle_asynchronously :update_products!, queue:'AFTER_ORDER_ITEM_STATS' if Rails.env.production?

end
