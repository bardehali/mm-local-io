class Scraper::Aliexpress < Scraper::Base

  HAS_MULTIPLE_LOCALE_VERSIONS = true

  # /category/100003109/women-clothing.html
  CATEGORY_URL_REGEX = /\/category\/(\d+)\/.+(\.html)?/i

  # /wholesale?SearchText=kaws&d=y&origin=n&catId=0
  SEARCH_URL_REGEX = /\/wholesale\?.*searchtext=([\w\+\._]+).*/i

  # /item/2018-new-arrived-fashion-women-blouse-long-sleeved-printed-women-top-stand-collar-blouses-slim-fit/32913075576.html?
  PRODUCT_URL_REGEX = /\/item(\/.+)?\/(\d+)(\.html)?/i

  # /store/515922?spm=2114.10010108.100005.1.753d6fa7Fgj7dL
  SELLER_URL_REGEX = /\/store\/(\d+)(\?[^\/]+)?\Z/i

  # @return <String> one of those Scraper::Page::PAGE_TYPES
  def self.page_type_for(page_or_url)
    url = url_of_page(page_or_url)
    if url =~ PRODUCT_URL_REGEX
      'detail'
    elsif url =~ CATEGORY_URL_REGEX || url =~ SEARCH_URL_REGEX
      'index'
    elsif url =~ SELLER_URL_REGEX
      'store'
    else
      'landing'
    end
  end

  PAGINATED_PATH_REGEXP = /\/(\d+)(\.html?)?$/i

  def self.find_pagination_number(uri_or_url)
    if page_type_for(uri_or_url) == 'index'
      m = uri_or_url.uri.path.match(PAGINATED_PATH_REGEXP).try(:[], 1)
      (m || '1').to_i
    else
      nil
    end
  end

  TRASH_PARAMETERS_REGEXP = /((initiative_id|_[a-z]|s[a-z]m[a-z\-_]*)=[^=&]+)/

  ##
  # Often has URL w/o scheme "//aliexpress.com/blahblah"
  def self.clean_page_url(page_url)
    page_type = page_type_for(page_url)
    if page_type == 'detail'
      page_url.gsub(TRASH_PARAMETERS_REGEXP, '').uri.to_s
    else
      page_url.to_s.gsub(TRASH_PARAMETERS_REGEXP, '')
    end
  end

  # @return <Array of ::Mechanize::Page::Link>
  def find_index_links(page, &block)
    page.links_with(href: CATEGORY_URL_REGEX)
  end

  # @return <Array of ::Mechanize::Page::Link>
  def find_seller_links(page, &block)
    page.links_with(href: SELLER_URL_REGEX)
  end

  # @return <Array of ::Mechanize::Page::Link>
  def find_product_links(page, &block)
    page.links_with(href: PRODUCT_URL_REGEX )
  end

  REMOVEABLE_TITLE_SEGMENTS_REGEXP = /((on\s+)?(aliexpress|alibaba|taobao)?(\.[a-z]{2,3})?\s*\|\s*(Aliexpress|Alibaba)(\s+group)?)\Z/i

  # @return <Hash of item attributes, keys symbolized>
  def find_product_attributes(page, &block)
    attr = {}
    attr[:title] = find_title_from_h1(page) || find_title_from_title_tag(page)
    attr[:title].gsub!(REMOVEABLE_TITLE_SEGMENTS_REGEXP, '') if attr[:title]
    attr[:price] = find_price_by_itemprop(page) || find_price_in_section(page) || find_price_by_text(page) || find_price_from_json(page)
    attr[:price].gsub!(/\A([a-z]{2,3}\s*\$?)/i, '') if attr[:price].is_a?(String) && attr[:price].present?
    attr[:description] = find_description_from_meta(page) || find_description_in_section(page) || find_description_by_text(page)
    if attr[:description] =~ /^\s*$/i
      attr[:description] = find_description_via_ajax(page)
    end
    attr[:specs] = find_product_specs(page)
    attr[:photos] = find_product_photos(page)
    attr[:store] = find_retail_store_attributes(page)
    attr[:categories] = find_categories_object(page).to_json
    [:title, :description, :categories].each do|a|
      attr[a] = attr[a].try(:encode_to_utf8)
    end
    attr
  end

  def find_json_value_of(page_or_source, key)
    source = page_or_source.is_a?(::Mechanize::Page) ? page_or_source.body : page_or_source
    source.scan( (/["']?#{key}["']?:\s*["']?([^"',]+)["']?/i ) ).first.try(:first)
  end

  STORE_NAME_FROM_TITLE_REGEXP = /from\s+(.+)\s+on\s+aliexpress(\.com)?/i

  # Search for links w/ store URL pattern.
  # Found cases when actual HTML is not rendered out initially but genreated by JS 
  # with data like: "storeName":"Melodydropshop777 Store","storeNum":1906405,"storeURL":"//www.aliexpress.com/store/1906405",
  # @return <Hash of Retail::Site attributes>
  def find_retail_store_attributes(page)
    h = {}
    link = page.links.find do|link| 
      link_url = (link.href || link.attributes['data-href']).to_s
      if link_url =~ SELLER_URL_REGEX 
        h[:store_url] = link_url
        h[:retail_site_store_id] = $1
        h[:name] = link.text.strip if link.text.match(/\A\s*Store(\s+home)?\s*\Z/i).nil?
      end
      h[:store_url]
    end
    h[:name] ||= STORE_NAME_FROM_TITLE_REGEXP.match(page.title.to_s).try(:[], 1)
    h[:store_url] ||= find_json_value_of(page, 'storeUrl')
    h[:retail_site_store_id] ||= find_json_value_of(page, 'storeNum') || find_json_value_of(page, 'storeNumber')
    h
  end

  # Thumbnails: https://ae01.alicdn.com/kf/HTB1bq_KXorrK1RkSne1q6ArVVXah/2018-new-arrived-fashion-women-blouse-long-sleeved-printed-women-top-stand-collar-blouses-slim-fit.jpg_50x50.jpg"
  # Larger pics: https://ae01.alicdn.com/kf/HTB1bq_KXorrK1RkSne1q6ArVVXah/2018-new-arrived-fashion-women-blouse-long-sleeved-printed-women-top-stand-collar-blouses-slim-fit.jpg

  PHOTO_URL_REGEX = /((https?:)?\/\/[\w\-\.]+\/kf\/[\w\-\.]+\/[\w\-\.]+\.(jpg|jpeg|png))/i
  THUMBNAIL_IMAGE_NAME_REGEX = /(_\d+x\d+)\.(jpg|jpeg|png)$/i

  def is_thumbnail?(url)
    THUMBNAIL_IMAGE_NAME_REGEX.match(url)
  end

  def find_product_photos(page, &block)
    list = Set.new
    page.content.scan(PHOTO_URL_REGEX).each do|url_vars|
      url = url_vars[0]
      next if is_thumbnail?(url)
      list << url
    end
    list
  end

  def find_product_specs(page, &block)
    specs = Set.new
    existing_spec_names = Set.new

    find_attribute_list(page).each do|dl|
      spec_name = dl.xpath('dt').first.try(:text)
      spec_value_node = dl.xpath('dd').first
      if spec_name.present? && spec_value_node
        spec_name = spec_name.strip.gsub(/(:)\s*$/, '' )
        ul_list = spec_value_node.xpath('ul')
        if ul_list
          ul_list.each do|ul|
            ul.xpath('li').each do|li|
              if spec_name =~ /colors?$/i && (color_link = li.xpath('a[@title]').first )
                specs << ::Retail::ProductSpec.new(name: spec_name, value_1: color_link['title'].strip )
              else
                specs << ::Retail::ProductSpec.new(name: spec_name, value_1: li.text.squeeze )
              end
            end
          end
        else
          specs << ::Retail::ProductSpec.new(name: spec_name, value_1: spec_value_node.text.squeeze )
        end
        existing_spec_names << spec_name
      end
    end

    find_spec_list(page).each do|li|
      spec_name = nil
      spec_values = []
      li.children.each do|span|
        next if span.text.strip.blank?
        if spec_name.nil?
          spec_name = span.text.strip.gsub(/(:)\s*$/, '' )
        else
          spec_values << span.text.strip
        end
      end
      if !existing_spec_names.include?(spec_name) && spec_values.present?
        specs << ::Retail::ProductSpec.new(name: spec_name, value_1: spec_values[0], value_2: spec_values[1] )
      end
    end

    specs.to_a
  end

  def find_categories_object(page)
    list = []
    page.xpath("//*[@class='ui-breadcrumb']//a | //*[@class='ui-breadcrumb']//span").each do|el|
      if el.text.match( /^\s*Back|home|all\s+categor\s*/i ).nil? && el.text.match( /^[\w\s]+/ )
        if el.name == 'a'
          list << { name: el.text, url: el['href'] }
        else
          list << {name: el.text }
        end
      end
    end
    if list.empty?
      category_id = find_json_value_of(page, 'categoryId')
      if category_id
        list << { other_site_category_id: category_id }
      end
    end
    list
  end


  ##########################################################

  protected

  ###############################################
  # Title

  PRODUCT_TITLE_HEADER_CLASS = 'product-name'

  def find_title_from_h1(page)
    nodes = page.xpath("//h1[@class='#{PRODUCT_TITLE_HEADER_CLASS}']")
    nodes.first.try(:text).try(:strip)
  end

  def find_title_from_title_tag(page)
    page.title.gsub(/(\s+on\s+aliexpress(\.com)?(\s*alibaba\s+group)?)$/i, '')
  end

  #################################################
  # Description

  def find_description_from_meta(page)
    find_meta(page, 'description')
  end

  def find_description_in_section(page)
    ( page.xpath("//*[@id='product-description']").first || page.xpath("//*[@class='description-content']").first || page.xpath("//*[@data-role='description']").first
    ).try(:text).try(:strip)
  end

  def find_description_by_text(page)
    started_quote = false
    s = ''
    body_text_only(page).split("\n\n").each do|p|
      if started_quote
        if p =~ /\*Recent\s+Reviews\b/i
          started_quote = false
        else
          s << p.strip
        end
      elsif p =~ /^\s*Product\s+Description\b/i
        started_quote = true
      end
    end
    s
  end

  # Example of URL: https://aeproductsourcesite.alicdn.com/product/description/pc/v2/en_US/desc.htm?productId=32999010386&key=HTB1QGgaVCzqK1RjSZPxM7Q4tVXaK.zip&token=828d1254c6836136bd80f0a7e4f0b75e
  DESCRIPTION_VIA_AJAX_REGEX = /["'](([\w\.\/:]*\w+\.com)?\/product\/description.+?\?.*productId=(\d+)[^"']*)["']/i
  DESCRIPTION_IN_AJAX_XPATH = "//div[@class='detailmodule_html']"

  ##
  #
  def find_description_via_ajax(page)
    desc = nil
    link_m = page.body.match( DESCRIPTION_VIA_AJAX_REGEX )
    if link_m
      BG_LOGGER.info "  getting description via #{link_m[1]}"
      agent = page.mech
      full_url = link_m[1]
      full_url.insert(0, 'http:') if full_url.start_with?('//')
      ajax_page = agent.get( full_url )
      desc = ajax_page.at_xpath(DESCRIPTION_IN_AJAX_XPATH).try(:text)
    end
    desc
  end

  #################################################
  # specs

  def find_attribute_list(page)
    page.xpath("//*[@class='product-attribute-main']//dl")
  end

  def find_spec_list(page)
    page.xpath("//ul[contains(@class,'product-property-list')]//li")
  end


  #################################################
  # Price

  PRICE_FORMAT = /\b?(\d+(\.\d+)?)/i

  def find_price_by_itemprop(page)
    price = nil
    page.xpath("//*[@itemprop='price']").find do|n|
      if price.nil? && ( m = n.text.match(PRICE_FORMAT) )
        price = m[1].to_f
      end
    end
    price
  end

  def find_price_in_section(page)
    price_nodes = page.xpath("//*[@class='p-price']")
    price = nil
    price_nodes.reverse.find do|n|
      if price.nil? && ( m = n.text.match(PRICE_FORMAT) )
        price = m[1].to_f
      end
    end
    price
  end

  TEXT_ONLY_PRICE_REGEX = /price:\s+(US\s*)?\$(\d+(\.\d+)?)/i

  # Find label of Price: and search text after
  def find_price_by_text(page)
    text = body_text_only(page)
    price_s = text.match(TEXT_ONLY_PRICE_REGEX).try(:[], 2)
    price_s.present? ? price_s : nil
  end

  ##
  # In some cases price w/o proper text could only be found in JS's JSON:
  # ,"formatedActivityPrice":"US $10.79","formatedPrice":"US $11.99","hiddenBigSalePrice":false,
  def find_price_from_json(page)
    price_s = find_json_value_of(page,'formatedActivityPrice') || find_json_value_of(page,'formatedPrice')
    price_s.present? ? price_s : nil
  end

end
