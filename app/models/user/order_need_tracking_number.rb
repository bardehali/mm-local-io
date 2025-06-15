module User
  class OrderNeedTrackingNumber < OrderMessage

    after_create :update_user_stats!

    def self.level
      1400
    end

    def overriding_level
      image_uploader = self.image&.url.present? ? self.image : nil
      image_uploader ||= self.is_a?(User::OrderNeedTrackingNumber) ? order.proof_of_payment : nil
      image_uploader.url.blank? ? self.class.level : self.class.level + 100
    end

    def show_only_to_recipient?
      false
    end

    def recipient_must_respond?
      true
    end

    def update_user_stats!
      if (paypal_store_pm = recipient.store&.paypal_store_payment_method)
        count_of_paid_need_tracking = recipient.calculate_count_of_paid_need_tracking_not_responded
        should_require_critical_response = recipient.should_require_critical_response?(count_of_paid_need_tracking)
        paypal_store_pm.same_store_payment_methods.includes(:store).each do|spm|
          stat = ::User::Stat.find_or_initialize_by(user_id: spm.store.user_id, name: ::Spree::User::COUNT_OF_PAID_NEED_TRACKING)
          stat.value = '%06d' % [count_of_paid_need_tracking]
          stat.save

          if should_require_critical_response
            require_stat = ::User::Stat.find_or_create_by(user_id: spm.store.user_id, name: ::Spree::User::REQUIRED_CRITICAL_RESPONSE)
          end
        end
      end
    end

    #def must_respond_with_class
    #  User::OrderProvidedTrackingNumber
    #end
  end
end