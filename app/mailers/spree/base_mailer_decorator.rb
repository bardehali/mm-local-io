module Spree
  module BaseMailerDecorator
    def self.prepended(base)
      base.helper HelperMethods
    end


    #############################
    # User based methods

    ##
    # Get the most likely recipient user based on argument or instance variables
    # defined in mailer generation methods
    def recipient_user(user = nil)
      user || @recipient || @user
    end

    ##
    # Checks locale of user or recipient for conditional/dynamic delivery method or server settings.
    # Modifies delivery method or settings if needed after calling w/ Spree::BaseMailer#mail
    #
    def mail(headers = {}, &block)
      m = super(headers, &block)

      check_to_apply_settings(m)
      m
    end

    protected

    ##
    # Check if should change settings like delivery dependent on seller of source country
    # @m [Mail::Message]
    def check_to_apply_settings(m)
      Spree::User.logger.debug "| #{m.subject} to #{recipient_user}, seller? #{recipient_user&.seller?}, in_source_country? #{recipient_user&.in_source_country?}"
      if (recipient = recipient_user)
        selected_email_service = nil
        is_china_email = ::Spree::User.matching_countries_for_email(recipient.email).include?('china')
        Spree::User.logger.debug "| email #{recipient.email} is_china_email? #{is_china_email}"
        if recipient.seller? && is_china_email # recipient.in_source_country?
          selected_email_service = 'aliyun'
        elsif recipient.buyer? || !is_china_email
          selected_email_service = 'gmail'
        end

        if selected_email_service
          more_settings = DynamicSmtpSettingsInterceptor.smtp_settings_of(selected_email_service)
          if more_settings && more_settings.size > 0
            Spree::User.logger.debug "| overriding SMTP settings w/ #{selected_email_service}: #{more_settings}"
            check_to_apply_from_address(m, more_settings)
            m.delivery_method Rails.configuration.action_mailer.delivery_method, more_settings
          end
        end
      end
    end

    ##
    # @m [Mail::Message]
    def check_to_apply_from_address(m, email_service_settings)
      is_recipient_the_seller = @order ? (@order.seller_user_id == recipient_user.id) : false
      if email_service_settings[:from].blank? && email_service_settings[:user_name].present? # safer w/ registered subdomain for this service
          m.from = "iOffer #{is_recipient_the_seller ? 'Helper' : 'Marketplace'} <#{email_service_settings[:user_name]}>"
      end
    end

    module HelperMethods

      ######################
      # Global methods

      def host
        @@host ||= Rails.application.config.action_mailer.default_url_options[:host]
      end

      ##
      # Only product needs full URL w/ domain; else would be relative.
      def full_asset_path(relative_path)
        asset_path = ActionController::Base.helpers.asset_path(relative_path)
        Rails.env.staging? ? URI.join('https://www.ioffer.com', asset_path).to_s : URI.join(host, asset_path).to_s
      end

      def full_logo_path(version = 'w200')
        full_asset_path("logo/iOffer_logo_color_#{version}.png")
      end

      def current_currency
        @order&.store.try(:default_currency) || Spree::Store.admin_store.default_currency
      end

      def full_payment_service_url(payment_method)
        payment_method.forward_payment_url
      end
    end
  end
end

Spree::BaseMailer.prepend(Spree::BaseMailerDecorator) if Spree::BaseMailer.included_modules.exclude?(Spree::BaseMailerDecorator)