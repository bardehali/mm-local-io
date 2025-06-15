module User
  class OrderShipped < OrderMessage

    def subject_evaluated
      I18n.t("message.#{type_id}.subject",  { shipping_method: shipping_method_name, shipment_tracking: shipment_tracking }).strip
    end

    # Common instance methods

    def shipping_method_name
      order.shipments.first&.shipping_method ? order.shipments.first&.shipping_method&.name : ''
    end

    def shipment_tracking
      order.shipments.first ? order.shipments.first&.tracking : ''
    end

  end
end