class Scraper::Chanzsneakers < Scraper::Base

  PRODUCT_URL_REGEX = /\/product\/\w+/
  CATEGORY_OR_KEYWORD_URL_REGEX = /\/product\-category\/\w+/

  def self.page_type_for(page_or_url)
    url = url_of_page(page_or_url)
    if url =~ PRODUCT_URL_REGEX
      'detail'
    elsif url =~ CATEGORY_OR_KEYWORD_URL_REGEX
      'index'
    else
      'landing'
    end
  end

  def find_product_attributes(page, &block)
    attr = {}
    attr[:name] = find_title_from_h1(page) || find_title_from_title_tag(page)
    attr[:price] = find_price_in_section(page)
    if attr[:price].to_f > 0
      attr[:price] = adjust_price(attr[:price])
    end
    attr[:description] = find_description_in_section(page)
    attr[:description] = find_description_tab(page) if attr[:description].blank?

    Scraper::Page.logger.info "| D: #{attr[:description]}"

    attr[:categories] = find_categories_object(page).to_json
    attr[:specs] = find_product_specs(page)
    attr[:photos] = find_product_photos(page)

    attr
  end

  def find_categories_object(page)
    list = []
    page.xpath("//div[contains(@class,'summary-inner')]//nav").children.each do|nav_child|
      if nav_child.name == 'a' && (nav_child.text.match(/\bhome|uncategorized\b/i) ).nil?
        list << { name: nav_child.text.strip, url: nav_child['href'] }
      end
    end
    list
  end

  def find_product_specs(page, &block)
    specs = []
    specs
  end

  def adjust_price(price)
    if price > 100.0
       90
    elsif price == 90.0
      price
    else
      [30, price - 30 ].max
    end
  end

  protected

  PRODUCT_TITLE_HEADER_CLASS = 'product_title'

  def find_title_from_h1(page)
    nodes = page.xpath("//h1[@itemprop='name']")
    nodes.first.try(:text).try(:strip)
  end

  def find_title_from_title_tag(page)
    page.title.gsub(/(\s+for\s+sale|\s*\-\s*chanz\s+sneakers)\Z/i, '')
  end

  def find_price_in_section(page)
    page.xpath("//*[contains(@class,'summary-inner')]/*[contains(@class,'price')]").collect(&:text).first.try(:gsub, '$', '').try(:strip).to_f
  end

  def find_description_in_section(page)
    page.xpath("//*[@itemprop='description']").text.strip
  end

  def find_description_tab(page)
    page.xpath("//*[@id='tab-description']").text.strip
  end


  def find_product_photos(page)
    page.xpath("//div[contains(@class,'product-image-wrap')]//img[@data-src]").collect{|n| n['data-src'] }
  end


end