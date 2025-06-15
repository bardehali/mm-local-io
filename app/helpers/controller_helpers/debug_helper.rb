module ControllerHelpers::DebugHelper
  extend ActiveSupport::Concern
  
  ##################################
  # Debugging

  def self.included(base)

    if base.respond_to?(:helper)
      base.helper ::ControllerHelpers::DebugHelper
    end
  end

  def debugging?
    %w(development sample).include?(Rails.env) || is_admin?
  end

  def is_admin?
    signed_in? ? (spree_current_user.try(:admin?) == true) : false
  end

  def need_to_captcha_verify?
    country = find_country
    logger.debug "| need_to_captcha_verify? #{country}"
    if Rails.env.production? && Recaptcha.configuration.site_key.present? && Recaptcha.configuration.secret_key.present?
      !Recaptcha::EXCLUDED_COUNTRIES.include?(country&.downcase)
    else
      false
    end
  end
end