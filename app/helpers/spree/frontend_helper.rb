##
# Modified clone of original Spree source.
module Spree
  module FrontendHelper
    include InlineSvg::ActionView::Helpers

    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def store_country_iso(store)
      store ||= current_store
      return unless store
      return unless store.default_country

      store.default_country.iso.downcase
    end

    def stores
      @stores ||= Spree::Store.includes(:default_country)
    end

    def store_currency_symbol(store)
      store ||= current_store
      return unless store
      return unless store.default_currency

      ::Money::Currency.find(store.default_currency).symbol
    end

    def spree_breadcrumbs(taxon, _separator = '', product = nil)
      return '' if current_page?('/') || taxon.nil?

      # breadcrumbs for root
      crumbs = [content_tag(:li, content_tag(
        :a, content_tag(
          :span, Spree.t(:home), itemprop: 'name'
        ) << content_tag(:meta, nil, itemprop: 'position', content: '0'), itemprop: 'url', href: spree.root_path
      ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: spree.root_path), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')]

      if taxon
        ancestors = taxon.ancestors.where.not(parent_id: nil)

        # breadcrumbs for ancestor taxons
        crumbs << ancestors.each_with_index.map do |ancestor, index|
          content_tag(:li, content_tag(
            :a, content_tag(
              :span, ancestor.name, itemprop: 'name'
            ) << content_tag(:meta, nil, itemprop: 'position', content: index + 1), itemprop: 'url', href: seo_url(ancestor, params: permitted_product_params)
          ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: seo_url(ancestor, params: permitted_product_params)), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')
        end

        # breadcrumbs for current taxon
        crumbs << content_tag(:li, content_tag(
          :a, content_tag(
            :span, taxon.name, itemprop: 'name'
          ) << content_tag(:meta, nil, itemprop: 'position', content: ancestors.size + 1), itemprop: 'url', href: seo_url(taxon, params: permitted_product_params)
        ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: seo_url(taxon, params: permitted_product_params)), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')

        # breadcrumbs for product
        if product
          crumbs << content_tag(:li, content_tag(
            :span, content_tag(
              :span, product.name, itemprop: 'name'
            ) << content_tag(:meta, nil, itemprop: 'position', content: ancestors.size + 2), itemprop: 'url', href: spree.product_path(product, taxon_id: taxon&.id)
          ) << content_tag(:span, nil, itemprop: 'item', itemscope: 'itemscope', itemtype: 'https://schema.org/Thing', itemid: spree.product_path(product, taxon_id: taxon&.id)), itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement', class: 'breadcrumb-item')
        end
      else
        # breadcrumbs for product on PDP
        crumbs << content_tag(:li, content_tag(
          :span, Spree.t(:products), itemprop: 'item'
        ) << content_tag(:meta, nil, itemprop: 'position', content: '1'), class: 'active', itemscope: 'itemscope', itemtype: 'https://schema.org/ListItem', itemprop: 'itemListElement')
      end
      crumb_list = content_tag(:ol, raw(crumbs.flatten.map(&:mb_chars).join), class: 'breadcrumb', itemscope: 'itemscope', itemtype: 'https://schema.org/BreadcrumbList')
      content_tag(:nav, crumb_list, id: 'breadcrumbs', class: 'col-12 mt-1 mt-sm-3 mt-lg-4', aria: { label: Spree.t(:breadcrumbs) })
    end

    def class_for(flash_type)
      {
        success: 'success',
        registration_error: 'danger',
        error: 'danger',
        alert: 'danger',
        warning: 'warning',
        notice: 'success'
      }[flash_type.to_sym]
    end

    def checkout_progress(numbers: false)
      states = @order.checkout_steps - ['complete']
      items = states.each_with_index.map do |state, i|
        text = Spree.t("order_state.#{state}").titleize
        text.prepend("#{i.succ}. ") if numbers

        css_classes = ['text-uppercase nav-item']
        current_index = states.index(@order.state)
        state_index = states.index(state)

        if state_index < current_index
          css_classes << 'completed'
          link_content = content_tag :span, nil, class: 'checkout-progress-steps-image checkout-progress-steps-image--full'
          link_content << text
          text = link_to(link_content, spree.checkout_state_path(state), class: 'd-flex flex-column align-items-center', method: :get)
        end

        css_classes << 'next' if state_index == current_index + 1
        css_classes << 'active' if state == @order.state
        css_classes << 'first' if state_index == 0
        css_classes << 'last' if state_index == states.length - 1
        # No more joined classes. IE6 is not a target browser.
        # Hack: Stops <a> being wrapped round previous items twice.
        if state_index < current_index
          content_tag('li', text, class: css_classes.join(' '))
        else
          link_content = if state == @order.state
                           content_tag :span, nil, class: 'checkout-progress-steps-image checkout-progress-steps-image--full'
                         else
                           inline_svg_tag 'circle.svg', class: 'checkout-progress-steps-image'
                         end
          link_content << text
          content_tag('li', content_tag('a', link_content, class: "d-flex flex-column align-items-center #{'active' if state == @order.state}"), class: css_classes.join(' '))
        end
      end
      content = content_tag('ul', raw(items.join("\n")), class: 'nav justify-content-between checkout-progress-steps', id: "checkout-step-#{@order.state}")
      hrs = '<hr />' * (states.length - 1)
      content << content_tag('div', raw(hrs), class: "checkout-progress-steps-line state-#{@order.state}")
    end

    def flash_messages(opts = {})
      flashes = ''
      excluded_types = opts[:excluded_types].to_a.map(&:to_s)

      flash.to_h.except('order_completed').each do |msg_type, text|
        next if msg_type.blank? || excluded_types.include?(msg_type)

        flashes << content_tag(:div, class: "alert alert-#{class_for(msg_type)} mb-0") do
          content_tag(:button, '&times;'.html_safe, class: 'close', data: { dismiss: 'alert', hidden: true }) +
            content_tag(:span, text)
        end
      end
      flashes.html_safe
    end

    def link_to_cart(text = nil)
      text = text ? h(text) : Spree.t('cart')
      css_class = nil

      if simple_current_order.nil? || simple_current_order.item_count.zero?
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{Spree.t('empty')})"
        css_class = 'empty'
      else
        text = "<span class='glyphicon glyphicon-shopping-cart'></span> #{text}: (#{simple_current_order.item_count})
                <span class='amount'>#{simple_current_order.display_total.to_html}</span>"
        css_class = 'full'
      end

      link_to text.html_safe, spree.cart_path, class: "cart-info nav-link #{css_class}"
    end

    def asset_exists?(path)
      if Rails.env.production? || Rails.env.staging?
        Rails.application.assets_manifest.find_sources(path).present?
      else
        Rails.application.assets.find_asset(path).present?
      end
    end

    def plp_and_carousel_image(product, image_class = '')
      image = default_image_for_product_or_variant(product)

      image_url = if image.present?
                    # URI.relative_url( main_app.url_for(image.url('plp')) )
                    cdn_image_url(image, :product)
                  else
                    asset_path('noimage/plp.png')
                  end

      image_style = image&.style(:plp)

      lazy_image(
        src: image_url,
        srcset: image_url,
        alt: product.name,
        width: image_style&.dig(:width) || 278,
        height: image_style&.dig(:height) || 371,
        class: "product-component-image d-block mw-100 #{image_class}"
      )
    rescue Exception => image_e
      Spree::Product.logger.warn "** plp_and_carousel_image problem for #{product.id}: #{image_e.message}"
      image_tag( asset_path('noimage/plp.png'), class: image_class.is_a?(Hash) ? image_class[:class] : image_class, alt:'' )
    end

    def lazy_image(src:, alt:, width:, height:, srcset: '', **options)
      # We need placeholder image with the correct size to prevent page from jumping
      placeholder = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20#{width}%20#{height}'%3E%3C/svg%3E"

      image_tag placeholder, data: { src: src, srcset: srcset }, class: "#{options[:class]} lazyload", alt: alt
    end

    def permitted_product_params
      # product_filters = available_option_types.map(&:name)
      # params.permit(product_filters << :sort_by)
      params.permit(*::Spree::MoreProductsHelper::PERMITTED_FILTER_PARAMS)
    end

    def carousel_image_source_set(image)
      return '' unless image

      widths = { lg: 1200, md: 992, sm: 768, xs: 576 }
      set = []
      widths.each do |key, value|
        # file = main_app.url_for(image.url("plp_and_carousel_#{key}"))
        file = cdn_image_url(image, "plp_and_carousel_#{key}")

        set << "#{file} #{value}w"
      end
      set.join(', ')
    end

    def image_source_set(name)
      widths = {
        desktop: '1200',
        tablet_landscape: '992',
        tablet_portrait: '768',
        mobile: '576'
      }
      set = []
      widths.each do |key, value|
        filename = key == :desktop ? name : "#{name}_#{key}"
        file = asset_path("#{filename}.jpg")

        set << "#{file} #{value}w"
      end
      set.join(', ')
    end

    def taxons_tree(root_taxon, current_taxon, max_level = 1)
      return '' if max_level < 1 || root_taxon.leaf?

      content_tag :div, class: 'list-group' do
        taxons = root_taxon.children.map do |taxon|
          css_class = current_taxon&.self_and_ancestors&.include?(taxon) ? 'list-group-item list-group-item-action active' : 'list-group-item list-group-item-action'
          link_to(taxon.name, seo_url(taxon), class: css_class) + taxons_tree(taxon, current_taxon, max_level - 1)
        end
        safe_join(taxons, "\n")
      end
    end

    def set_image_alt(image)
      return image.alt if image.alt.present?
    end

    def icon(name:, classes: '', width:, height:)
      inline_svg_tag "#{name}.svg", class: "spree-icon #{classes}", size: "#{width}px*#{height}px"
    end

    def price_filter_values
      price_filters.collect{|h| h[:name] }
    end

    def price_filters
      price_marks = [10, 50, 100, 150, 200]
      lower_end = nil
      list = []
      price_marks.each_with_index do|price, i|
        if lower_end.nil?
          list << { name: "#{I18n.t('activerecord.attributes.spree/product.less_than')} #{formatted_price(price)}",
            filter: { range: { price:{ lt: price } }} }
        elsif i == price_marks.length - 1
          list << { name: "#{I18n.t('activerecord.attributes.spree/product.more_than')} #{formatted_price(price)}",
            filter: { range: { price:{gt: price } }} }
        else
          list << { name: "#{formatted_price(lower_end)} - #{formatted_price(price)}",
            filter: { range: { price:{gt: lower_end, lte: price } }} }
        end
        lower_end = price
      end
      list
    end

    def static_filters
      @static_filters ||= Spree::Frontend::Config[:products_filters]
    end

    def additional_filters_partials
      @additional_filters_partials ||= Spree::Frontend::Config[:additional_filters_partials]
    end

    def filtering_params
      @filtering_params ||= available_option_types.map(&:filter_param).concat(static_filters)
    end

    def filtering_params_cache_key
      @filtering_params_cache_key ||= params.permit(*filtering_params)&.reject { |_, v| v.blank? }&.to_param
    end

    def available_option_types_cache_key
      @available_option_types_cache_key ||= Spree::OptionType.maximum(:updated_at)&.utc&.to_i
    end

    def sorted_option_values_map
      @sorted_option_values_map ||= Rails.cache.fetch("sorted_option_values_map") do
        Spree::OptionValue.for_public.joins(:product_count_stat).includes(:product_count_stat).
          where('record_count > 0').order('record_count desc').group_by(&:option_type_id)
      end
    end

    ##
    # Either taxon-based or all available.
    def filter_option_types(options = {})
      if @taxons.present?
        list = @taxons.collect(&:closest_searchable_option_types).flatten.uniq
        list = Spree::OptionType.where('id=0') if list.nil? || list.is_a?(Array)
        select_sorted_option_values_for(list, option_values_limit: options[:option_values_limit] || 10) if list.present?
        list
      else
        available_option_types(option_values_limit: options[:option_values_limit] || 10)
      end
    end

    ##
    # Fetch or set cache of option_values of option_types that have products associated with.
    # @options
    #   :taxon_id [Integer] limit option_types to be only taxon#searchable_option_types; else all
    #   :option_values_limit [Integer] limit count of option values in option_type.selected_option_values
    def available_option_types(options = {})

      # Next would set taxon searchable_option_types if given taxon_id
      @available_option_types ||= Rails.cache.fetch("available-option-types/#{available_option_types_cache_key}") do
        list = Spree::OptionType.all # includes(:option_values).to_a
        select_sorted_option_values_for(list, options)
        list
      end
      @available_option_types
    end

    ##
    # Set @option_types each selected_option_values w/ top opton_values
    def select_sorted_option_values_for(option_types, options = {})
      option_values_limit = options[:option_values_limit]
      # taxon_id = options[:taxon_id]
      map = sorted_option_values_map
      option_types.includes(:option_values_for_public).each do|ot|
        ov_list = map[ot.id] || ot.option_values_for_public
        ot.selected_option_values = ( option_values_limit ?
          ov_list[0, option_values_limit].sort_by(&:position) : ov_list ).sort_by(&:position)
      end if option_types.present?
      option_types
    end

    def spree_social_link(service)
      return '' if current_store.send(service).blank?

      link_to "https://#{service}.com/#{current_store.send(service)}", target: :blank, rel: 'nofollow noopener', 'aria-label': service do
        content_tag :figure, id: service, class: 'px-2' do
          icon(name: service, width: 22, height: 22)
        end
      end
    end

    def checkout_available_payment_methods
      @order.available_payment_methods(current_store)
    end

    def color_option_type_name
      @color_option_type_name ||= Spree::OptionType.color&.name
    end

    def find_location_by_ip(ip)
      begin
        ip = ENV['REQUEST_IP'] if (Rails.env.development? || Rails.env.test?) && ENV['REQUEST_IP'].present?
        MaxMind::GeoIP2::Model::Country.reader.country(ip)
      rescue MaxMind::GeoIP2::AddressNotFoundError
        nil
      rescue Exception => e
        logger.warn "| Problem fetching country by IP: #{e}"
        nil
      end
    end

    def find_country_code_by_ip(ip)
      location = find_location_by_ip(ip)
      location&.country&.iso_code
    end

    ##
    # More flexible, safer call than country_flag_icon because sometimes user.country is set but
    # country_code not set.
    # @user [Spree::User]
    def country_flag_icon_of(user, more_html_options = {}, &block)
      return '' if user.nil?
      country_flag_icon(user.country_code || user.country&.to_country_code, more_html_options, &block)
    end

    def country_flag_icon(country_iso_code = nil, more_html_options = {}, &block)
      return '' if country_iso_code.blank?
      existing_class_value = more_html_options[:class] || more_html_options['class']
      content_tag :span, nil, more_html_options.merge(class: "flag-icon flag-icon-#{country_iso_code.downcase} #{existing_class_value}", title: more_html_options[:title] || more_html_options['title'] || country_iso_code), &block
    end

    ##
    # New public methods here one

    def make_color_select(color_value, selected = false)
      content_tag(:svg, class: 'color-select', height: 32, width: 32, viewBox: "0 0 32 32", xmlns: 'http://www.w3.org/2000/svg' ) do
        content_tag(:g, class:'color-select-border', fill:'none', 'fill-rule'=>'evenodd') do
          content_tag(:circle, class: "#{'color-select-border--selected' if selected} plp-overlay-color-item",  cx: 16, cy: 16, r: 15, 'stroke-width' => 2 ) { } +
          content_tag(:g, transform: 'translate(2 2)') do
            content_tag(:circle, cx: 14, cy: 14, fill: color_value, 'fill-rule'=>'evenodd', r: 12) {} +
            content_tag(:circle, cx: 14, cy: 14, stroke: '#ffffff', 'stroke-width'=> 2) {}
          end
        end
      end
    end

    private

    def formatted_price(value)
      Spree::Money.new(value, currency: current_currency, no_cents_if_whole: true).to_s
    end

    def credit_card_icon(type)
      available_icons = %w[visa american_express diners_club discover jcb maestro master]

      if available_icons.include?(type)
        image_tag "credit_cards/icons/#{type}.svg", class: 'payment-sources-list-item-image'
      else
        image_tag 'credit_cards/icons/generic.svg', class: 'payment-sources-list-item-image'
      end
    end

    def checkout_edit_link(step = 'address')
      classes = 'align-text-bottom checkout-confirm-delivery-informations-link'

      link_to spree.checkout_state_path(step), class: classes, method: :get do
        inline_svg_tag 'edit.svg'
      end
    end
  end
end
