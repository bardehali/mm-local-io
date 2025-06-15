class ApplicationController < ActionController::Base
  include Spree::Core::ControllerHelpers::Auth
  include ::ControllerHelpers::GeoFence

  helper_method :user_group, :source_country?

  def action
    params[:action].to_sym
  end

  def after_sign_in_path_for(resource)
    if resource.is_a?(Spree::User) && resource.admin?
      browser.device.mobile? && request.path.index('/login') == 0 ? '/admin/msales' : '/admin/dashboard'
    else
      if (user_return_to = params[:return_to] || session['spree_user_return_to']).present?
        session['spree_user_return_to'] = nil
        user_return_to
      elsif session[:reset_password_source] == 'email'
        ioffer_brands_path
      elsif resource&.seller?
        '/admin/sales/payment'
      elsif resource&.buyer?
        '/account'
      else
        '/'
      end
    end
  end

  def after_sign_out_path_for(resource)
    new_spree_user_session_path
  end

  def user_group
    if spree_current_user.nil?
      'guest'
    elsif spree_current_user.admin?
      'admin'
    elsif spree_current_user.seller?
      'seller'
    elsif spree_current_user.buyer?
      'buyer'
    else
      'user'
    end
  end

  ###########################
  # iOffer

  def current_user
    unless @current_user
      signed_in_user_code = session[:signed_in_user]
      @current_user = signed_in_user_code ? ::Ioffer::User.where(username: ::Ioffer::User.decrypt(signed_in_user_code) ).first : nil
    end
    @current_user
  end
  helper_method :current_user

  def log_in(ioffer_user, sign_in_spree_user = true)
    session[:signed_in_user_id] = ioffer_user.id if ioffer_user.id
    session[:signed_in_user] = ::Ioffer::User.encrypt(ioffer_user.username) if ioffer_user.username.present?

    if sign_in_spree_user
      spree_user = ioffer_user.convert_to_spree_user!
      sign_in(spree_user)
    end
  end

  def log_out
    session[:signed_in_user_id] = nil
    session[:signed_in_user] = nil
    sign_out
  end

  ##
  # If not exist, set some random key
  def assign_client_id
    client_id = cookies[:client_id]
    if client_id.blank?
      client_id = "ioffer#{Time.now.to_s(:db).gsub(/[\s\-\:]/,'')}"
      client_id << ( 920831742653 + rand(1000000000000) ).to_s(36)
      client_id << ( 306417528639 + rand(1000000000000) ).to_s(36)
      cookies[:client_id] = client_id
    end
    client_id
  end

  # @model [User or EmailSubscription]
  def set_user_info_to_model(model)
    model.ip = request.remote_ip
    model.session = session.to_h if model.respond_to?(:session)
    model.cookies = cookies.to_h
    model.client_id = cookies[:client_id]
  end

  ##################################
  # Debugging

  def debugging?
    %w(development sample).include?(Rails.env) || is_admin?
  end
  helper_method :debugging?

  def is_admin?
    signed_in? ? (spree_current_user.try(:admin?) == true) : false
  end
  helper_method :is_admin?

  def need_to_captcha_verify?
    country = find_country
    logger.debug "| need_to_captcha_verify? #{country}"
    if Rails.env.production? && Recaptcha.configuration.site_key.present? && Recaptcha.configuration.secret_key.present?
      !Recaptcha::EXCLUDED_COUNTRIES.include?(country&.downcase)
    else
      false
    end
  end
  helper_method :need_to_captcha_verify?

  ##
  # Commonly used check whether incomplete or not acceptable should not be shown to admins
  # while the owner sees all of own created.
  def show_only_acceptable_products?
    spree_current_user.nil? || (spree_current_user&.admin? ? params[:status] == 'acceptable' : false)
    # (@user && @user&.id != spree_current_user&.id) # no need for this as admin intentionally limits by current regular user
  end
  helper_method :show_only_acceptable_products?

  #######################
  # Common search methods

    ##
  # General raw string wrapper of matching words
  def highlight_keywords(value, keywords_to_match = nil, prefix: '<strong>', postfix:'</strong>')
    keywords_to_match ||= SearchKeyword.clean_chars(params[:keywords])
    # logger.debug "| keywords_to_match: #{keywords_to_match}"
    return value if keywords_to_match.blank?
    value ? value.wrap_matches(keywords_to_match, prefix: prefix, postfix: postfix).html_safe : ''
  end

  helper_method :highlight_keywords

end
