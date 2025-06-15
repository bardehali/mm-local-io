class SetupStdShippingPopulateZones < ActiveRecord::Migration[6.0]
  def change
    Spree::Zone.populate_zones

    shipm = Spree::ShippingMethod.find_or_create_by(name: "Standard Delivery") do|sh|
      sh.attributes = { display_on: "both", admin_name: "Skip Choice of Shipping Method", 
        tax_category_id: Spree::TaxCategory.default.id, available_to_all: true, 
        available_to_users: true }
      sh.shipping_categories = [Spree::ShippingCategory.default]
      sh.calculator ||= Spree::Calculator::Shipping::FlatPercentItemTotal.new(
        calculable_type:'Spree::ShippingMethod', preferences:{ flat_percent: 0.0 } )
    end
  end
end

