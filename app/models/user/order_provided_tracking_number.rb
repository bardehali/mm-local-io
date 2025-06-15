module User
  class OrderProvidedTrackingNumber < OrderMessage
    after_create :save_in_shipment!
    after_create :schedule_to_send_email

    def subject_in_html
      "#{I18n.t('order.tracking') }: <a href=\"https://www.google.com/search?q=#{CGI.escape(comment.to_s) }\" target=\"_target\" rel='noreferrer'>#{comment}</a>"
    end

    def comment_evaluated
      ''
    end

    def should_highlight?
      false
    end

    def save_in_shipment!
      if record
        shipment = record.shipments.last
        shipment ||= Spree::Shipment.new(order_id: record.id, state:'pending', stock_location_id: Spree::StockLocation.first&.id)
        shipment.tracking = comment.strip
        shipment.save
      end
    end

    def schedule_to_send_email
      return true if self.recipient.nil? || self.recipient.fake_user? || self.sender&.phantom_seller? || self.recipient.phantom_seller?
      
      Spree::OrderMailer.with(message: self, order: self.record).tracking_to_buyer.deliver
    rescue Exception => e
      UserReport::EmailDelivery.report_delivery_error(self, e, recipient_user_id)
    end
    handle_asynchronously :schedule_to_send_email, queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE if Rails.env.production?
  end
end