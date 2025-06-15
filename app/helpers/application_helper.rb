module ApplicationHelper

  def current_store
    nil
  end

  def default_title
    t('site_name')
  end

  def title
    @page_title.present? ? @page_title : @title
  end

  def orders_in_cart
    @orders
  end

  def cart_items
    @cart_items ||= @orders.to_a.collect(&:line_items).flatten
  end

  def cart_subtotal
    cart_items.collect(&:amount).sum
  end

  def user_api_hidden_tag(html_options = {})
    hidden_field_tag(:token, spree_current_user.try(:spree_api_key), html_options)
  end

  def form_authen_token_hidden_tag(html_options = {})
    hidden_field_tag(:authenticity_token, form_authenticity_token, html_options)
  end

  def recaptcha_wrapper(record)
    error = nil
    if record
      error = record.errors[:captcha_verified].first
    end
    content_tag(:div, id:'captcha_wrapper', style: error.present? ? 'padding: 0.5rem; border: solid 1px red;' : '') do
      hidden_field_tag('recaptcha', params[:recaptcha]) +
      recaptcha_tags +
      if error.present?
        content_tag(:div, class:'recaptcha-error-message text-danger') { error }
      end
    end
  end

  ##################################
  # View rendering

  def user_label(user, show_email = false)
    last_label = user.try(:id) == Spree::User.fetch_admin.id ? 'admin' : "User (#{user.id})"
    user.try(:username) || (show_email ? user.try(:email) : nil) || last_label
  end

  ##
  # Would show short time if less than a week.
  # @return [String]
  def relative_short_time(time)
    time_obj = time.is_a?(ActiveSupport::TimeWithZone) ? time.time : time
    if time > 1.week.ago && time >= time_obj.beginning_of_week
      time.strftime('%a %l:%M %p')
    else
      time.strftime('%-m/%-d/%y %l:%M %p')
    end
  end

  def short_display_of_time(time, html_options = {})
    if time
       content_tag(:label, html_options.merge(title: time.to_s(:db)) ) { relative_short_time(time) }
    else
      ''
    end
  end

  ###
  # Use of distance_of_time_in_words to render like "(about|over|less than) %d %unit".
  # And convert the prefix words to symbols ~, >, <
  def distance_of_time_in_shorts(from_time, to_time = nil, options = {})
    to_time ||= Time.now
    s = distance_of_time_in_words(from_time, to_time, options).dup
    s.gsub!(/\A(about)\b/i, '~ ')
    s.gsub!(/\A(less\s+than)\b/i, '< ')
    s.gsub!(/\A(over)\b/i, '> ')
    s
  end

  def distance_of_time_in_abbreviations(from_time, to_time = nil, options = {})
    to_time ||= Time.now
    distance_of_time_in_words(from_time, to_time, options.reverse_merge(scope: 'datetime.distance_in_words.short'))
  end
  alias_method :distance_of_time_in_abbr, :distance_of_time_in_abbreviations

  def timestamp_with_slashes(time)
    time ? time.strftime('%m/%d/%Y %k:%M') : ''
  end

  def create_product_display_variant_adoption?
    @create_product_display_variant_adoption ||= Rails.cache.fetch('CREATE_PRODUCT_DISPLAY_VARIANT_ADOPTION_IF_NONE') { false } == true
  end

  ##
  # Add protocol + host of @request, like https://www.ioffer.com
  def to_full_url(page_path)
    page_path =~ /\A[a-z]+:\/\// ? page_path : "#{request.protocol}#{request.host}#{page_path}"
  end

  ##
  # If exists display_variant_adoption, would use route show_product_by_variant_adoption.
  # Else depends on create_product_display_variant_adoption? whether to auto create one,
  # or move onto next route show_product_by_variant
  def product_rep_url(product, other_link_params = {})
    display_va = product.display_variant_adoption
    display_va = product.rep_variant_adoption if display_va.nil? && create_product_display_variant_adoption?
    if display_va
      main_app.show_product_by_variant_adoption_path(other_link_params.merge(variant_adoption_id: product.display_variant_adoption_slug) )
    else
      main_app.show_product_by_variant_path(other_link_params.merge(variant_id: product.rep_variant_slug) )
    end
  end

  # CDN_AVAILABLE = (!Rails.env.test?).freeze unless defined?(CDN_AVAILABLE)
  CDN_AVAILABLE = true

  # Image blob URL using active storage and prefixing w/ domain if has
  # @image [Spree::Image]
  def cdn_image_url(image, version = nil)
    cdn_available = CDN_AVAILABLE
    version_in_cdn = Spree::Image::IMAGE_VERSIONS_ON_CDN.include?(version&.to_sym)

    Rails.logger.debug("Starting cdn_image_url method with image: #{image.inspect}, version: #{version.inspect}, CDN_AVAILABLE: #{cdn_available}, VERSION_IN_CDN: #{version_in_cdn}")

    u = if CDN_AVAILABLE && Spree::Image::IMAGE_VERSIONS_ON_CDN.include?(version&.to_sym) && image.present?
      logger.debug("CDN is available and version is included in IMAGE_VERSIONS_ON_CDN")

      img = image.present? ? (version ? image.url(version) : image.attachment) : nil
      logger.debug("Selected img: #{img.inspect}")

      key = img.respond_to?(:key) ? img.key : img # no image is only String
      logger.debug("Determined key: #{key.inspect}")

      url = ActiveStorage::Blob.service.url(key).split('?').first.gsub('http:', 'https:')
      logger.debug("Generated URL from ActiveStorage: #{url.inspect}")
      url
    else

      url = 'noimage/.png'

      # url = main_app.url_for(image.url(version)).gsub('http:', 'https:')
      # logger.debug("Generated URL from main app: #{url.inspect}")
      # url

    end

    if u == 'noimage/.png'
      logger.debug("URL is 'noimage/.png', setting u to asset path")
      u = asset_path('noimage/plp.png')
    end

    logger.debug("Final URL: #{u.inspect}")
    u
  end

  ##
  # @return http://xxxxx
  def image_cloud_endpoint
    ImageUploader.fog_credentials[:endpoint] || ENV['MINIO_ENDPOINT'] || 'https://www.ioffer.com'
  end
  ##
  # Different from ActiveStorage or cdn_image_url because this uses fog configuration.
  def full_image_cloud_url(path = '/')
    path.starts_with?('http') ? path : URI.join( image_cloud_endpoint, path ).to_s
  end

  ##
  # The @option_value.extra_value should be the hex value of the color.  But if none, the
  # integer value could only be converted of string value to integer.
  def color_value(option_value)
    option_value.extra_value.present? ? Color.new(option_value.extra_value).hex_value : option_value.extra_value
  end

  ##
  # Based on converted integer value, would calculated the inverted side of the RGB value.
  def opposite_text_color_value(option_value)
    option_value.extra_value.present? ? Color.new(option_value.extra_value).opposite_text_value : option_value.extra_value
  end

  ##
  # Checks if t() renders missing transalation HTML. If missing, would return text in block.
  def t_missing_alternative(*args)
    result = t(*args)
    if result =~ /translation\s+missing/i
      result = yield
    end
    result
  end

  def parse_referer_url(url)
      return "" if url.blank?

      uri = URI.parse(url)
      path = uri.path
      query = CGI.parse(uri.query.to_s)

      # Mapping paths to categories
      category_map = {
        "/products_m" => "MSearch",
        "/products_s" => "DSearch",
        "/t/categories" => "Browse",
        "/vp/" => "Related"
      }

      # Determine category, prioritizing "Tile" if 'sid' is present
      category = if path.start_with?("/products_s") && query["sid"].present?
                   "Tile"
                 elsif path.start_with?("/vp/")
                   "Related"
                 else
                   category_map.find { |key, _| path.start_with?(key) }&.last || "Unknown"
                 end

      # Extracting page number (default to 1 if not found), but disregarding for VP
      page_number = query["page"]&.first || "1"
      page_string = path.start_with?("/vp/") ? "" : "P#{page_number}"

      # Extracting keywords
      if path.start_with?("/vp/")
        keywords = path.split("/")[2].to_s.split("-")[0..2].join(" ").titleize.strip
      else
        keywords = query["keywords"]&.first || query["utm_term"]&.first || path.split("/").last&.gsub(/[-_]/, ' ')
        keywords = keywords.to_s.split("?").first.to_s.titleize.strip
      end

      [category, page_string, keywords].reject(&:empty?).join("|")
    end


end
