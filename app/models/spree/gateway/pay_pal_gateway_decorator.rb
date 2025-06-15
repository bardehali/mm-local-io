
module Spree::Gateway::PayPalGatewayDecorator

  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def config
      @@config ||= YAML::load( File.open(File.join(Rails.root, 'config/paypal_api.yml')) )[Rails.env.to_s]
    end

    def client
      client_id = @@client_config.try(:[], 'client_id')
      client_secret = @@client_config.try(:[], 'client_secret')
      client_env_class = Rails.env.production? ? PayPal::LiveEnvironment : PayPal::SandboxEnvironment
      environment = client_env_class.new client_id, client_secret
      PayPal::PayPalHttpClient.new environment
    end

    ##
    # Util methods from Paypal https://developer.paypal.com/docs/checkout/reference/server-integration/setup-sdk/
    def openstruct_to_hash(object, hash = {})
      object.each_pair do |key, value|
        hash[key] = value.is_a?(OpenStruct) ? openstruct_to_hash(value) : value.is_a?(Array) ? array_to_hash(value) : value
      end
      hash
    end

    def array_to_hash(array, hash= [])
      array.each do |item|
        x = item.is_a?(OpenStruct) ? openstruct_to_hash(item) : item.is_a?(Array) ? array_to_hash(item) : item
        hash << x
      end
      hash
    end

    ##
    # Create the hash or array for the child of transaction/order parameters, purchase_units
    def make_purchase_units_params(order)
      
    end
  end
  
  ##
  # Called by payment.capture!
  def capture(amount, response_code, gateway_options)
    Spree::Payment.logger.debug "| capture: amount #{amount}, response_code #{response_code}, gateway_options #{gateway_options}"
    ActiveMerchant::Billing::Response.new(
      true, nil, {}, gateway_options
    )
  end
  
end

Spree::Gateway::PayPalGateway.prepend(Spree::Gateway::PayPalGatewayDecorator) if Spree::Gateway::PayPalGateway.included_modules.exclude?(Spree::Gateway::PayPalGatewayDecorator)

