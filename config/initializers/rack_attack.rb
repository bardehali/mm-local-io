class Rack::Attack

  require 'ipaddr'
  require 'json'
  require 'net/http'
  require 'openssl'

  #search terms: rack attack, rack_attack
  ### Configure Cache ###

  # If you don't want to use Rails.cache (Rack::Attack's default), then
  # configure it here.
  #
  # Note: The store is only used for throttling (not blocklisting and
  # safelisting). It must implement .increment and .write like
  # ActiveSupport::Cache::Store

  # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  class Request < ::Rack::Request
    # Use 'X-Real-IP' header to get the real IP address
    def ip
      @env['HTTP_X_REAL_IP'] || super
    end
  end

  ### Throttle Spammy Clients ###
  Rack::Attack.blocklist('block specific IP') do |request|
      #request.ip == '68.162.96.249'
  end

  # config/initializers/rack-attack.rb
  # Get the IP addresses of googlebot as an array

  # Fetch and parse the JSON file to get Googlebot IP ranges
  def self.fetch_google_urls
    url = URI('https://developers.google.com/static/search/apis/ipranges/googlebot.json')
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Skip SSL verification

    request = Net::HTTP::Get.new(url)
    response = http.request(request)
    data = JSON.parse(response.body)

    urls = data['prefixes'].map do |prefix|
      prefix['ipv4Prefix']
    end.compact
    urls
  end

  # Initialize a list of IPAddr objects for Googlebot IPs
  GOOGLEBOT_IP_RANGES = fetch_google_urls.map do |range|
    IPAddr.new(range) rescue nil # Safely ignore invalid entries
  end.compact

  # Allow requests from Googlebot IP ranges
  Rack::Attack.safelist('allow from GoogleBot') do |req|
    req.get? && GOOGLEBOT_IP_RANGES.any? { |range| range.include?(req.ip) }
  end

  # Fetch and parse the JSON file to get BingBot IP ranges
  def self.fetch_bing_urls
    url = URI('https://www.bing.com/toolbox/bingbot.json')
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Skip SSL verification

    request = Net::HTTP::Get.new(url)
    response = http.request(request)
    data = JSON.parse(response.body)

    urls = data['prefixes'].map do |prefix|
      prefix['ipv4Prefix']
    end.compact
    urls
  end

  # Initialize a list of IPAddr objects for Googlebot IPs
  BINGBOT_IP_RANGES = fetch_bing_urls.map do |range|
    IPAddr.new(range) rescue nil # Safely ignore invalid entries
  end.compact

  # Allow requests from Googlebot IP ranges
  Rack::Attack.safelist('allow from BingBot') do |req|
    req.get? && BINGBOT_IP_RANGES.any? { |range| range.include?(req.ip) }
  end

  # Allow unlimited requests for logged in users
  Rack::Attack.safelist('allow logged in users') do |request|
    # Assumes the application defines a method `current_user` that returns
    # the user object if logged in or nil if not. This method depends on
    # your authentication setup.
    # You might need to adjust this to fit how your application manages sessions.
    request.env['warden'].authenticated? # for Devise
    # OR, for other authentication solutions:
    # !request.session[:user_id].nil?
  end

  # If any single client IP is making tons of requests, then they're
  # probably malicious or a poorly-configured scraper. Either way, they
  # don't deserve to hog all of the app server's CPU. Cut them off!
  #
  # Note: If you're serving assets through rack, those requests may be
  # counted by rack-attack and this throttle may be activated too
  # quickly. If so, enable the condition to exclude them from tracking.

  # Throttle all requests by IP (60rpm)
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
  throttle('req/ip', limit: 100, period: 10.minutes) do |req|
    # Current time window
    ## current_period = (Time.now.to_i / 10.minutes.to_i).to_s

    # Construct the cache key
    ## cache_key = "rack::attack:#{current_period}:req/ip:#{req.ip}"

    # Fetch the current request count from the cache
    ##request_count = Rails.cache.read(cache_key).to_i

    # Log the request IP and the current count
    ## Rails.logger.info "Request IP: #{req.ip}, Request Count: #{request_count}"

    #Throttle based on IP requests/10 minutes except images for product images.
    req.ip unless (req.path.start_with?('/rails/active_storage/representations') || req.path.start_with?('/admin') || req.path.start_with?('/assets') || req.path.start_with?('/search_keywords') ||  req.path.start_with?('/account_link') || req.path.start_with?('/cart_link') || req.path.start_with?('/products') || req.path.start_with?('/api_tokens') )
  end

  throttle('req/ip/day', limit: 500, period: 24.hours) do |req|

    # Current time window
    ## current_period = (Time.now.to_i / 24.hours.to_i).to_s

    # Construct the cache key
    ## cache_key = "rack::attack:#{current_period}:req/ip/day:#{req.ip}"

    # Fetch the current request count from the cache
    ## request_count = Rails.cache.read(cache_key).to_i

    #Throttle based on IP requests/day address except images for product images.
    ## Rails.logger.info "Request IP: #{req.ip}, Request Count: #{request_count}"

    req.ip unless (req.path.start_with?('/rails/active_storage/representations') || req.path.start_with?('/admin') || req.path.start_with?('/assets') || req.path.start_with?('/search_keywords') || req.path.start_with?('/account_link') || req.path.start_with?('/cart_link') || req.path.start_with?('/products') || req.path.start_with?('/api_tokens')  )
  end


  ### Prevent Brute-Force Login Attacks ###

  # The most common brute-force login attack is a brute-force password
  # attack where an attacker simply tries a large number of emails and
  # passwords to see if any credentials match.
  #
  # Another common method of attack is to use a swarm of computers with
  # different IPs to try brute-forcing a password for a specific account.

  # Throttle POST requests to /login by IP address
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end

  # Throttle POST requests to /login by email param
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{normalized_email}"
  #
  # Note: This creates a problem where a malicious user could intentionally
  # throttle logins for another user and force their login requests to be
  # denied, but that's not very common and shouldn't happen to you. (Knock
  # on wood!)
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/login' && req.post?
      # Normalize the email, using the same logic as your authentication process, to
      # protect against rate limit bypasses. Return the normalized email if present, nil otherwise.
      req.params['email'].to_s.downcase.gsub(/\s+/, "").presence
    end
  end

  ### Custom Throttle Response ###

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
end
