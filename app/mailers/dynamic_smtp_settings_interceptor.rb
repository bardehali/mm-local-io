class DynamicSmtpSettingsInterceptor
  ##
  # @return [Hash] could be empty if no such setting of this @service_name
  def self.smtp_settings_of(service_name)
    settings = nil
    if Rails.application.config.respond_to?(:dynamic_smtp_settings)
      settings = Rails.application.config.dynamic_smtp_settings[service_name]
    end
    settings || {}
  end

  def self.delivering_email(message)
    
    # Change this to be seller && in source country
    # settings = 
     # if message.to.any?{|to_email| ::Spree::User.matching_countries_for_email(to_email).include?('china') }
    #    smtp_settings_of('aliyun')
    #  else
    #    smtp_settings_of('gmail')
    #  end
    #message.delivery_method :smtp, settings
  end
end