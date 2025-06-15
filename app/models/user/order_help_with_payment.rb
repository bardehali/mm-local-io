module User
  class OrderHelpWithPayment < OrderMessage

    def self.level
      ORDER_LEVEL
    end

    def overriding_level
      image_uploader = self.image&.url.present? ? self.image : nil
      image_uploader ||= self.is_a?(User::OrderNeedTrackingNumber) ? order.proof_of_payment : nil
      image_uploader.nil? || image_uploader.url.blank? ? self.class.level : self.class.level + 100
    end

    def show_only_to_recipient?
      false
    end
  end
end