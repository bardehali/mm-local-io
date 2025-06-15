class AddMissingOfSolidus < ActiveRecord::Migration[6.0]
  def change
    Spree::Product.connection.execute('ALTER TABLE friendly_id_slugs ADD updated_at datetime')

    add_column_unless_exists :spree_users, :supplier_id, :integer
    add_column_unless_exists :spree_users, :username, :string, limit: 64
    add_column_unless_exists :spree_users, :display_name, :string, limit: 64
    add_column_unless_exists :spree_users, :country, :string, limit: 64
    add_column_unless_exists :spree_users, :country_code, :string, limit: 64
    add_column_unless_exists :spree_users, :zipcode, :string, limit: 64
    add_column_unless_exists :spree_users, :timezone, :string, limit: 64
    add_column_unless_exists :spree_users, :non_paying_buyer_count, :integer, default: 0
    add_column_unless_exists :spree_users, :gross_merchandise_sales, :float, default: 0.0


    add_column_unless_exists :spree_roles, :created_at, :datetime
    add_column_unless_exists :spree_roles, :updated_at, :datetime

    add_column_unless_exists :spree_role_users, :created_at, :datetime
    add_column_unless_exists :spree_role_users, :updated_at, :datetime

    add_column_unless_exists :spree_products, :user_id, :integer
    add_column_unless_exists :spree_products, :master_product_id, :integer
    add_column_unless_exists :spree_products, :view_count, :integer, default: 0
    add_column_unless_exists :spree_products, :transaction_count, :integer, default: 0
    add_column_unless_exists :spree_products, :engagement_count, :integer, default: 0
    add_column_unless_exists :spree_products, :gms, :float, default: 0.0
    add_column_unless_exists :spree_products, :curation_score, :integer, default: 0
    add_column_unless_exists :spree_products, :retail_site_id, :integer
    add_column_unless_exists :spree_products, :status_code, :integer
    add_column_unless_exists :spree_products, :last_review_at, :datetime
    add_column_unless_exists :spree_products, :iqs, :integer, default: 20
    add_column_unless_exists :spree_products, :images_count, :integer, default: 0

    add_column_unless_exists :spree_variants, :user_id, :integer
    add_column_unless_exists :spree_variants, :view_count, :integer, default: 0
    add_column_unless_exists :spree_variants, :transaction_count, :integer, default: 0
    add_column_unless_exists :spree_variants, :sorting_rank, :string, limit: 36
    add_column_unless_exists :spree_variants, :gms, :float, default: 0.0

    add_column_unless_exists :spree_prices, :country_iso, :string, limit: 16

    add_column_unless_exists :spree_products_taxons, :created_at, :datetime
    add_column_unless_exists :spree_products_taxons, :updated_at, :datetime

    add_column_unless_exists :spree_option_types, :searchable_text, :boolean, default: false
    add_index_unless_exists :spree_option_types, :searchable_text

    add_column_unless_exists :spree_option_values, :extra_value, :string, limit: 64
    add_column_unless_exists :spree_option_values, :user_id, :integer
    add_column_unless_exists :spree_option_values, :is_default, :boolean, default: false

    add_column_unless_exists :spree_payments, :payable_id, :integer
    add_column_unless_exists :spree_payments, :payable_type, :string, limit: 64

    add_column_unless_exists :spree_payment_methods, :preference_source, :string, limit: 255
    add_column_unless_exists :spree_payment_methods, :available_to_users, :boolean, default: true
    add_column_unless_exists :spree_payment_methods, :available_to_admin, :boolean, default: true

    add_column_unless_exists :spree_line_items, :product_id, :integer

    add_column_unless_exists :spree_inventory_units, :carton_id, :integer

    add_column_unless_exists :spree_stock_items, :user_id, :integer

    add_column_unless_exists :spree_stock_locations, :position, :integer, default: 1
    add_column_unless_exists :spree_stock_locations, :restock_inventory, :boolean, default: true
    add_column_unless_exists :spree_stock_locations, :fulfillable, :boolean, default: true
    add_column_unless_exists :spree_stock_locations, :check_stock_on_transfer, :boolean, default: true
    add_column_unless_exists :spree_stock_locations, :code, :string, limit: 255
    add_column_unless_exists :spree_stock_locations, :supplier_id, :integer

    add_column_unless_exists :spree_shipments, :deprecated_address_id, :integer
    add_column_unless_exists :spree_shipments, :supplier_commission, :float, default: 0.0

    add_column_unless_exists :spree_shipping_methods, :available_to_all, :boolean, default: true
    add_column_unless_exists :spree_shipping_methods, :available_to_users, :boolean, default: true
    add_column_unless_exists :spree_shipping_methods, :carrier, :string, limit: 255
    add_column_unless_exists :spree_shipping_methods, :service_level, :string, limit: 255
    add_column_unless_exists :spree_shipping_methods, :carrier, :boolean, limit: 255
    add_column_unless_exists :spree_shipping_methods, :store_id, :integer

    add_column_unless_exists :spree_shipping_method_zones, :created_at, :datetime
    add_column_unless_exists :spree_shipping_method_zones, :updated_at, :datetime

    add_column_unless_exists :spree_adjustments, :promotion_code_id, :integer
    add_column_unless_exists :spree_adjustments, :adjustment_reason_id, :integer
    add_column_unless_exists :spree_adjustments, :finalized, :boolean, default: false

    add_column_unless_exists :spree_assets, :fingerprint, :string, limit: 64

    add_column_unless_exists :spree_countries, :created_at, :datetime

    add_column_unless_exists :spree_states, :created_at, :datetime

    add_column_unless_exists :spree_prototype_taxons, :created_at, :datetime
    add_column_unless_exists :spree_prototype_taxons, :updated_at, :datetime

    add_column_unless_exists :spree_reimbursement_credits, :created_at, :datetime
    add_column_unless_exists :spree_reimbursement_credits, :updated_at, :datetime
    
    add_column_unless_exists :spree_reimbursements, :created_at, :datetime
    add_column_unless_exists :spree_reimbursements, :updated_at, :datetime

    add_column_unless_exists :spree_promotion_actions, :preferences, :text
    add_column_unless_exists :spree_promotion_actions, :created_at, :datetime
    add_column_unless_exists :spree_promotion_actions, :updated_at, :datetime

    add_column_unless_exists :spree_orders, :approver_name, :string, limit: 255
    add_column_unless_exists :spree_orders, :frontend_viewable, :boolean, default: true
    add_column_unless_exists :spree_orders, :transaction_code, :string, limit: 255
    add_column_unless_exists :spree_orders, :seller_user_id, :integer
    add_column_unless_exists :spree_orders, :guest_token, :string, limit: 255

    add_column_unless_exists :spree_promotion_rule_taxons, :created_at, :datetime
    add_column_unless_exists :spree_promotion_rule_taxons, :updated_at, :datetime

    add_column_unless_exists :spree_product_promotion_rules, :created_at, :datetime
    add_column_unless_exists :spree_product_promotion_rules, :updated_at, :datetime

    add_column_unless_exists :spree_promotion_action_line_items, :created_at, :datetime
    add_column_unless_exists :spree_promotion_action_line_items, :updated_at, :datetime

    add_column_unless_exists :spree_promotions, :per_code_usage_limit, :integer
    add_column_unless_exists :spree_promotions, :apply_automatically, :boolean, default: false

    add_column_unless_exists :spree_return_items, :return_reason_id, :integer

    add_column_unless_exists :spree_stores, :cart_tax_country_iso, :string, limit: 255
    add_column_unless_exists :spree_stores, :available_locales, :string, limit: 255
    add_column_unless_exists :spree_stores, :user_id, :integer

    add_column_unless_exists :spree_store_credits, :type_id, :integer
    add_column_unless_exists :spree_store_credits, :invalidated_at, :datetime

    add_column_unless_exists :spree_store_credit_events, :update_reason_id, :integer
    add_column_unless_exists :spree_store_credit_events, :amount_remaining, :float
    add_column_unless_exists :spree_store_credit_events, :store_credit_reason_id, :integer

    add_column_unless_exists :spree_refund_reasons, :code, :string, limit: 255

    add_column_unless_exists :spree_tax_rates, :starts_at, :datetime
    add_column_unless_exists :spree_tax_rates, :expires_at, :datetime

    add_column_unless_exists :spree_taxons, :icon_file_name, :string, limit: 255
    add_column_unless_exists :spree_taxons, :icon_content_type, :string, limit: 255
    add_column_unless_exists :spree_taxons, :icon_file_size, :integer
    add_column_unless_exists :spree_taxons, :icon_updated_at, :datetime
  end
end
