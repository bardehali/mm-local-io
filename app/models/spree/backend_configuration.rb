module Spree
  class BackendConfiguration < Preferences::Configuration
    preference :locale, :string, default: Rails.application.config.i18n.default_locale

    ORDER_TABS         ||= [:orders, :payments, :creditcard_payments,
                            :shipments, :credit_cards, :return_authorizations,
                            :customer_returns, :adjustments, :customer_details]
    SELLER_ORDER_TABS ||= [:pending_payment, :user_messages, :waiting_shipping, :completed_sales]
    PRODUCT_TABS       ||= [:products, :option_types, :properties, :prototypes,
                            :variants, :product_properties, :taxonomies,
                            :taxons]
    ADOPTION_TABS        ||= [:wanted_products]
    REPORT_TABS        ||= [:reports]
    CONFIGURATION_TABS ||= [:configurations, :general_settings, :tax_categories,
                            :tax_rates, :zones, :countries, :states,
                            :payment_methods, :shipping_methods,
                            :shipping_categories, :stock_transfers,
                            :stock_locations, :trackers, :refund_reasons,
                            :reimbursement_types, :return_authorization_reasons,
                            :stores]
    PROMOTION_TABS     ||= [:promotions, :promotion_categories]
    USER_TABS          ||= [:users]
    RETAIL_TABS          ||= [:site_categories]
    SCRAPER_TABS          ||= [:scraper_pages]
  end
end
