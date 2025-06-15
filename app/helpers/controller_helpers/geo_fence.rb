##
# Key method is exception_path? method.  Here has the checking against ALTERNATE_PATH_EXCEPTIONS
# and ALTERNATE_PATH_EXCEPTIONS_REGEXP.  But inheriting class can override this for actions in that
# controller.
module ControllerHelpers::GeoFence
  extend ActiveSupport::Concern

  IpAndCountry = Struct.new(:ip, :country)

  included do

    PASSED_SESSION_KEY = 'passed_geofence_at'.freeze unless defined?(PASSED_SESSION_KEY)

    WHITELIST_IPS = %w(127.0.0.1 96.233.63.124 192.168.65.1 71.185.206.170 72.68.110.17 173.49.83.252 45.32.187.192 209.250.245.176 136.244.97.33 ::1).freeze unless defined?(WHITELIST_IPS)
    ALTERNATE_PATH_EXCEPTIONS = Set.new( ['/', '/home', '/seller_signup', '/login', '/logout', '/forbidden',
      '/signup', '/users', '/account_link', '/cart_link', '/account', '/payments',
      '/admin/', '/admin', '/admin/store_payment_methods', '/admin/payment_methods_and_retail_stores',
      '/select_payment_methods', '/other',
      '/admin/sales',
      '/brands', '/categories_brands', '/select_brands', '/what_categories'
    ] ).freeze unless defined?(ALTERNATE_PATH_EXCEPTIONS)

    ALTERNATIVE_PATH_EXCEPTIONS_REGEXP = /\A\/(admin(\/products|\/?\Z)|user\/|passwords?\/|payment_methods?|payment_options?|admin\/sales|admin\/(wanted_products|fill_your_shop|other_listings)|admin\/orders)/ unless defined?(ALTERNATIVE_PATH_EXCEPTIONS_REGEXP)

    MAX_TIME_OF_GEOFENCE_VARIABLES = 30.minutes unless defined?(MAX_TIME_OF_GEOFENCE_VARIABLES)

    HTML_CONTENT_TYPE_FORMATS = %w(text/html */* *) unless defined?(HTML_CONTENT_TYPE_FORMATS)

    IP_REGEXP = /\A[\d\.:]+\Z/ unless defined?(IP_REGEXP)

    before_action :scan_user_through_geo_fence unless Rails.env.test? || !respond_to?(:before_action)

    ###
    helper_method :find_country if respond_to?(:helper_method)

  end

  def scan_user_through_geo_fence
    # return unless html_page?
    # return if spree_current_user&.admin?
    log_last_active_at

    if spree_current_user&.seller? && spree_current_user&.required_critical_response? && must_redirect_to_critical_response?
      redirect_to "/admin/critical_response?t=#{Time.now.to_i}"

    elsif can_pass_geofence?
      go_to_alternate_homepage

    else
      go_to_blocked_page
    end
  end

  ################################
  # Helper methods, accessors

  ##
  # Ensure current user is actual seller; for adopted pages, check against approved seller.
  # If block given, would yield when authorization fails, which would provide caller
  # the freedom to respond, such as responding to different formats.
  def authorize_seller!(redirect_path = nil, &block)
    pass = if spree_current_user&.test_user?
        true
      elsif ['adopted', 'fill_your_shop', 'wanted_products', 'other_listings'].include?(params[:action] )
        Spree::Ability.new(spree_current_user).can?(:adopt, ::Spree::Product)
      else
        spree_current_user&.seller? || spree_current_user&.admin?
      end
    logger.info "| authorize_seller! - pass? #{pass} for #{spree_current_user}"
    unless pass
      if block_given?
        yield

      else
        if spree_current_user.nil?
          session['spree_user_return_to'] = redirect_path || request.path
          redirect_to login_path
        elsif redirect_path.present?
          redirect_to redirect_path
        else
          go_to_blocked_page(true)
        end
      end
    end
  end

  def log_last_active_at
    if spree_current_user && (spree_current_user.last_active_at.nil? || spree_current_user.last_active_at < 3.minutes.ago) && session[:sign_in_as_original_id].nil?
      spree_current_user.update_columns(last_active_at: Time.now)
      spree_current_user.last_active_at = Time.now
    end
  end

  def can_pass_geofence?
    cleanup_session_variables

    return true if !session[PASSED_SESSION_KEY].nil?

    private_network_range = IPAddr.new('172.16.0.0/12') # Covers 172.16.0.0 to 172.31.255.255
    ip = ENV['REQUEST_IP'] || request.remote_ip
    # logger.debug "| IP #{ip} in #{find_country(ip)}: #{request.method} #{request.path} => exception_path? #{exception_path?}, session #{session[PASSED_SESSION_KEY] }, signed_in? #{signed_in?}, accepted_location? #{accepted_location?(ip) }, accept_for_buyer? #{accepted_location_for_buyer?(ip) }"
    if ENV['REQUEST_COUNTRY'].blank? && ( WHITELIST_IPS.include?(ip) || private_network_range.include?(ip) )
      session[PASSED_SESSION_KEY] ||= Time.now
    else
      session[PASSED_SESSION_KEY] ||= accepted_location?(ip) || spree_current_user&.admin? ? Time.now : nil
    end
    !session[PASSED_SESSION_KEY].nil?
  end

  ##
  # Expire old passed_geofence_at
  def cleanup_session_variables
    if (at = session[PASSED_SESSION_KEY] )
      session[PASSED_SESSION_KEY] = nil if at < MAX_TIME_OF_GEOFENCE_VARIABLES.ago || Rails.env.development?
    end
  end

  def exception_path?
    request.path == '/' || ALTERNATE_PATH_EXCEPTIONS.include?(request.path) || !ALTERNATIVE_PATH_EXCEPTIONS_REGEXP.match(request.path).nil?
  end

  def accepted_location?(ip_or_country = nil)
    return true if can_skip_accepted_location? && spree_current_user&.test_user?

    country = find_ip_and_country(ip_or_country).country
    if country
      if Spree::User::ACCEPTED_COUNTRIES_FOR_FULL_SELLER.include?(country.downcase)
        true
      #else # if Spree::User::UNACCEPTED_COUNTRIES_FOR_FULL_SELLER.include?(country.downcase)
      # elsif Spree::User::ACCEPTED_COUNTRIES_FOR_BUYER_REGEXP.match(country)
      elsif accepted_location_for_buyer?(ip_or_country)
        true
      else
        false
      end
    else
      false
    end
  end

  def accepted_location_for_buyer?(ip_or_country = nil)
    country = find_ip_and_country(ip_or_country).country
    Spree::User::UNACCEPTED_COUNTRIES_FOR_BUYER.exclude?(country&.downcase)
  end

  #optimize this so we aren't doing this calculation twice
  def source_country?(ip_or_country = nil)
    session_key = "source_country_#{ip_or_country}"

    logger.debug "-> This is the referrer :::: #{request.referer}"
    logger.debug " .. about to call source_country?(#{ip_or_country}), can_skip_accepted_location? #{can_skip_accepted_location?}, session #{session[session_key]}"
    return true if can_skip_accepted_location? && spree_current_user&.test_user?
    return session[session_key] unless session[session_key].nil?

    country = find_ip_and_country(ip_or_country).country
    is_source_country = country && Spree::User::ACCEPTED_COUNTRIES_FOR_FULL_SELLER.include?(country.downcase)
    logger.debug "  .. calling source_country?(#{ip_or_country}) -> got #{country} -> is_source_country? #{is_source_country}"

    session[session_key] = is_source_country
    is_source_country
  end

  ##
  # For whiltelist IP or accepted country to pass fence,
  # except homepage changed to seller signup path.
  def go_to_alternate_homepage
    p = '/seller_signup' # ioffer_seller_signup_path
    if request.path == '/' && !exception_path?
      logger.debug " -> alt hp: #{p}"
      redirect_to p
    else
      # check_request_for_misbehaviors
    end
  end

  ##
  # For those being blocked from public pages.
  def go_to_blocked_page(ignore_exception_path = false)
    if ignore_exception_path || !exception_path?
      logger.debug " -> blocked_page"
      redirect_to '/'
    end
  end

  ##
  # Misbehaviors like busy requests, fetching security files
  def check_request_for_misbehaviors
=begin
    should_be_blocked = false
    Rack::Attack.blocklist('fail2ban pentesters') do |req|
      # `filter` returns truthy value if request fails, or if it's from a previously banned IP
      # so the request is blocked
      should_be_blocked = Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 10.minutes) do
        # The count for the IP is incremented if the return value is truthy
        CGI.unescape(req.query_string) =~ %r{/etc/passwd} || req.path.include?('/etc/passwd')
      end
    end

    if should_be_blocked
      logger.debug " .. blocking #{request.id} #{request.method} #{request.path}"
      render :file => "#{RAILS_ROOT}/public/404.html",  :status => 404
    end
=end
  end

  def find_ip
    ENV['REQUEST_IP'] || request.remote_ip
  end

  def find_country(ip = nil)

    ip ||= find_ip
    begin
      location = MaxMind::GeoIP2::Model::Country.reader.country(ip)
      @country = location&.country&.name
      logger.debug "| in country #{@country}"
    rescue MaxMind::GeoIP2::AddressNotFoundError
      # fake out country for testing
      @country = ENV['REQUEST_COUNTRY'] if Rails.env.development? || Rails.env.test?
    rescue Exception => e
      logger.warn "| Problem fetching country by IP: #{e}"
    end
    @country ||= spree_current_user&.country
    @country
  end

  ##
  # @return [IpAndCountry]
  def find_ip_and_country(ip_or_country)
    ip = ip_or_country && IP_REGEXP =~ ip_or_country ? ip_or_country : nil
    country = ip_or_country if ip.nil?
    country ||= find_country(ip)
    IpAndCountry.new(ip, country)
  end


  ##############################

  protected


  def html_page?
    HTML_CONTENT_TYPE_FORMATS.include?(request.format)
  end

  def can_skip_accepted_location?
    @@can_skip_accepted_location ||= !Rails.env.production? && !Rails.env.test?
  end

  # user lockout, user block, critical response turned off right now.
  def must_redirect_to_critical_response?
    # b = !request.format.to_s.match(/\bhtml\b/i).nil? && cannot_skip_critical_response?
    # logger.debug "| must_redirect_to_critical_response? #{b}"
    # b
    false
  end

  def cannot_skip_critical_response?
    /\A\/(logout|orders\/\w+\/messages?|admin\/(critical|update_options))/.match(request.path).nil?
  end

  def logger
    Spree::User.logger
  end
end
