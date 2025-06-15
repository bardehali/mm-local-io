class Scraper::Ioffer < Scraper::Base


  # sub-category browse page, filter link: /c/Bracelets-1015842/
  CATEGORY_URL_REGEX = /\/cl?\/(?<category_name>\w+\-)?(?<category_id>\d+)?\/?/i
  KEYWORD_INDEX_URL_REGEX = /\/cl?\/(?<category_name>\w+)?\/?$/i

  CATEGORY_OR_KEYWORD_URL_REGEX = Regexp.union(CATEGORY_URL_REGEX, KEYWORD_INDEX_URL_REGEX)

  # search: /search/items/nintendo+accessories
  SEARCH_URL_REGEX = /\/search\/items\/(?<query>.+)/i

  # /i/women-s-gold-rose-gold-black-silver-bracelet-551974848?i=202914393
  PRODUCT_URL_REGEX = /\/i\/[\w\-_]+$/i

  # /i/store-negotiation-529545558
  STORE_NEGOTIATION_REGEX = /\/i\/store\-negotiation/i

  HAS_MULTIPLE_LOCALE_VERSIONS = true

  # @return <String> one of those Scraper::Page::PAGE_TYPES
  def self.page_type_for(page_or_url)
    url = url_of_page(page_or_url)
    if url =~ PRODUCT_URL_REGEX
      'detail'
    elsif url =~ CATEGORY_OR_KEYWORD_URL_REGEX
      'index'
    elsif url =~ SELLER_URL_REGEX
      'store'
    else
      'landing'
    end
  end

  def self.find_pagination_number(uri_or_url)
    u = uri_or_url.uri
    (u.sorted_parameters[:page] || '1').to_i
  end

  # @return <Array of ::Mechanize::Page::Link>
  def find_index_links(page, &block)
    page.links_with(href: CATEGORY_OR_KEYWORD_URL_REGEX)
  end

  # @return <Array of ::Mechanize::Page::Link>
  def find_product_links(page, &block)
    list = page.links_with(href: PRODUCT_URL_REGEX )
    list.delete_if{|link| link.href =~ STORE_NEGOTIATION_REGEX }
    list
  end

  INVALID_ITEM_TITLE_REGEX = /(invalid\s+item)|(no\s+longer\+available)|(not\s+available)/i

  # @return <Hash of item attributes, keys symbolized>
  def find_product_attributes(page, &block)
    attr = {}
    attr[:title] = find_title_from_h1(page) || find_title_from_title_tag(page)
    return {} if attr[:title] =~ INVALID_ITEM_TITLE_REGEX

    attr[:price] = find_price_in_section(page) || find_price_by_text(page)
    attr[:description] = find_description_in_section(page) || find_description_by_text(page)
    attr[:categories] = find_categories_object(page).to_json
    attr[:specs] = find_product_specs(page)
    attr[:photos] = find_product_photos(page)
    attr[:store] = find_retail_store_attributes(page)
    attr
  end

  # @return <Hash of Retail::Site attributes>
  def find_retail_store_attributes(page)
    h = find_retail_store_in_section(page, "//*[@class='seller-details']//a")
    h = find_retail_store_in_section(page, "//*[@class='item-details']//a") unless h.size > 0
    h
  end

  SELLER_URL_REGEX = /\/selling\/(.+)$/i
  def find_retail_store_in_section(page, which_xpath)
    h = {}
    page.xpath(which_xpath).each do|link_node|
      if link_node['href'] =~ SELLER_URL_REGEX
        h[:store_url] = link_node['href']
        h[:retail_site_store_id] = $1
        h[:name] = link_node.text.strip unless link_node.text =~ /^\s*View\s+(seller|store)/i
      end
    end
    h
  end

  # https://cdn.iofferphoto.com/img/item/641/362/658/m-jewelry-bracelet-new-men-s-women-s-cuff-bracelet-22-d60b.jpg
  # (https?:\/\/(\w+\.)+[a-z]{2,3})?
  ITEM_IMAGE_URL_REGEX = /\/img\d?\/item(\/\d+)*\/.*[\-\w\.]+\.(jpe?g|png)/i

  # https://cdn.iofferphoto.com/t/JvXqVfcQM391As-PDjYmdumlOlA=/adaptive-fit-in/250x250/filters:fill(transparent)/img/item/641/362/658/o_m-jewelry-bracelet-new-men-s-women-s-cuff-bracelet-22-ac07.jpg
  # https://img.staticbg.com/images/oaupload/banggood/images/35/30/b25d2539-ca19-4bf2-beac-11e2ae5c2c60.jpg
  T_IMAGE_URL_REGEX = /\/t|images|img\/.+\.(jpe?g|png)/i

  MULTIPLE_IMAGE_URL_REGEX = Regexp.union(ITEM_IMAGE_URL_REGEX, T_IMAGE_URL_REGEX)

  def find_product_photos(page, &block)
    # page.images_with(src) is unreliable
    list = []
    page.xpath("//*[@id='item-gallery']//*[@data-src] | //*[@id='item-gallery']//img[@src]").each do|img|
      src = ( img.attributes['data-src'] || img.attributes['src'] ).try(:value).to_s
      list << src if src && src =~ MULTIPLE_IMAGE_URL_REGEX && !is_thumbnail?(src)
    end
    if list.blank?
      page.xpath("//*[@id='main-image']//img[@src]").each do|img|
        src = ( img.attributes['data-src'] || img.attributes['src'] ).try(:value).to_s
        list << src if src && src =~ MULTIPLE_IMAGE_URL_REGEX && !is_thumbnail?(src)
      end
    end
    list
  end

  def is_thumbnail?(url)
    uri = url.is_a?(::URI::HTTP) ? url : URI(url)
    parts = uri.request_uri.split('/')
    # some small photo's actual size is same as thumbnail
    parts.first == 't' || parts[1] == 't' || parts.last.start_with?('t_') || parts.include?('swatches')
  end

  def find_product_specs(page, &block)
    find_specs_in_section(page)
  end

  def find_categories_object(page)
    list = []
    page.xpath("//*[contains(@class,'category-breadcrumb')]//a").each do|link_el|
      list << { name: link_el.text.strip, url: link_el['href'] }
    end
    list
  end

  ##########################################################

  LOCALE_SWITCHING_URL = 'https://www.ioffer.com/languages/update?locale=%s'

  def switch_locale(locale = 'en-US')
    url = LOCALE_SWITCHING_URL % [locale]
    agent.get url
  end

  ##########################################################

  protected

  ###############################################
  # Title

  PRODUCT_TITLE_HEADER_CLASS = 'item-title'

  def find_title_from_h1(page)
    nodes = page.xpath("//h1[@class='#{PRODUCT_TITLE_HEADER_CLASS}']")
    nodes.first.try(:text).try(:strip)
  end

  def find_title_from_title_tag(page)
    page.title.gsub(/(\s+for\s+sale)$/i, '')
  end

  #################################################
  # Description

  def find_description_in_section(page)
    page.xpath("//*[@id='item-description']").first.try(:text).try(:strip)
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
      elsif p =~ /^\s*Item\s+Description\b/i
        started_quote = true
      end
    end
    s
  end

  #################################################
  # specs

  def find_spec_rows_in_item_information(page)
    page.xpath("//*[@id='item-information']//tr")
  end

  # @return <Array of Retail::ProductSpec>
  def find_specs_in_section(page)
    specs = []

    find_spec_rows_in_item_information(page).each do|row|
      spec = ::Retail::ProductSpec.new
      spec.keyword = row['class'] || row.xpath('td').find{|col| col.text.try(:strip).to_s != '' }.try(:text).try(:strip)
      spec_values = []

      row.children.each do|col|
        compact_content = col.content.squish
        next if compact_content.blank? && col.children.blank?
        if spec.name.nil?
          spec.name = col.text.squish.downcase
          # puts "| Name: #{spec.name}"
        elsif spec.name.present?
          if spec.name =~ /colors?\s*$/ || row['class'] =~ /\bcolors?$/
            find_color_swatches(col).each do|c|
              inner_spec = ::Retail::ProductSpec.new(name: spec.name, value_1: c)
              inner_spec.keyword = spec.keyword
              specs << inner_spec
            end
          elsif page.xpath(col.path + '//table').present?
            find_spec_values_from_table(col).each do|v|
              inner_spec = ::Retail::ProductSpec.new(name: spec.name, value_1: v)
              inner_spec.keyword = spec.keyword
              specs << inner_spec
            end
          else
            spec_values << col.text.squish
          end
          # puts "  values: #{compact_content} => #{spec_values}"
        end
      end
      if spec.name.present? && spec_values.size > 0
        spec.value_1 = spec_values[0]
        spec.value_2 = spec_values[1]
        specs << spec
      end
    end
    specs
  end

  ##
  # Some columns of a specification is organized within a table, such as available sizes.
  def find_spec_values_from_table(container)
    values = Set.new
    container.xpath(container.path + '//table//td'). each do|cell|
      values << cell.text.strip
    end
    values
  end

  SWATCH_COLOR_IMG_SRC_REGEX = /\/(.+)\.(png|jpe?g|gif)$/

  ##
  # These are color images representing images
  def find_color_swatches(container)
    colors = []
    container.xpath("//*[@class='swatches']//img").each do|color_img|
      if color_img['title'].present?
        colors << color_img['title'].strip
      elsif color_img['src'] =~ SWATCH_COLOR_IMG_SRC_REGEX
        colors << $1.split('/').last.titleize.downcase
      end
    end
    colors.flatten.uniq
  end

  #################################################
  # Price
  def find_price_in_section(page)
    price_nodes = page.xpath("//*[@class='item-price']")
    price = nil
    price_nodes.find do|n|
      if price.nil? && ( m = n.text.match /\$(\d+(\.\d+)?)/i )
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
    price_s.present? ? price_s.to_f : nil
  end

end
