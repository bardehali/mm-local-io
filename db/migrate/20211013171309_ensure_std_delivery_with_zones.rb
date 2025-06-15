class EnsureStdDeliveryWithZones < ActiveRecord::Migration[6.0]
  def change
    std_delivery = Spree::ShippingMethod.standard_delivery
    std_delivery ||= Spree::ShippingMethod.create(
      name:'Standard Delivery', display_on:'both', available_to_all: true,
      available_to_users: true
    )
    std_delivery.zones = Spree::Zone.all
  end
end
