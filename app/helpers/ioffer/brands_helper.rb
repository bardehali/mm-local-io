module Ioffer::BrandsHelper

  ##
  # Creates a box w/ checkbox
  # @which_payment [either Brand or String w/ Brand.name]
  def brand_card(which_brand, base_css_class = '')
    brand = which_brand.is_a?(Ioffer::Brand) ? which_brand : Ioffer::Brand.where(name: which_brand).first
    return content_tag(:i) if brand.nil?
    icon_path = asset_path("brands/#{brand.name.downcase}.png")
    has_brand = current_user ?
      current_user.user_brands.collect(&:brand_id).include?(brand.id) : nil
    content_tag(:div, class:"col-sm brand-card-wrapper #{base_css_class}#{' brand-selected' if has_brand}", title: brand.display_name, 'data-toggle'=>'tooltip' ) do
      concat check_box_tag('brand_ids[]', brand.id, has_brand, id:"brand_checkbox_#{brand.id}" )
      concat image_tag(icon_path, alt: brand.display_name)
    end
  end

  ##
  # Rendering of rows of brand cards.
  def make_brand_cards(base_css_class = '')
    rows = []
    current_columns = []
    Ioffer::Brand.not_created_by_users.all.each_with_index do|brand, index|
      current_columns << brand_card(brand, base_css_class)
      if current_columns.size >= 5
        rows << content_tag(:div, class:'row') do
          current_columns.each do|col|
            concat col
          end
        end
        current_columns.clear
      end
    end
    # left over
    if current_columns.size > 0
      rows << content_tag(:div, class:'row') do
        current_columns.each do|col|
          concat col
        end
      end
      current_columns.clear
    end

    rows.each do|row|
      concat row
    end
  end

  ##
  # Creates a box w/ checkbox
  # @which_payment [either Spree::OptionValue or String w/ name]
  def brand_option_value_card(which_brand, base_css_class = '')
    @brand_ot ||= Spree::OptionType.find_by(name:'brand')
    brand = which_brand.is_a?(Spree::OptionValue) ? which_brand : 
      @brand_ot.option_values.where(presentation: which_brand).first
    return content_tag(:i) if brand.nil?
    icon_path = asset_path("brands/#{brand.name.downcase.gsub(/(\s+)/, '')}.png")
    has_brand = spree_current_user ?
      spree_current_user.user_selling_option_values.collect(&:option_value_id).include?(brand.id) : nil
    content_tag(:div, class:"col-sm brand-card-wrapper #{base_css_class}#{' brand-selected' if has_brand}", title: brand.presentation, 'data-toggle'=>'tooltip' ) do
      concat check_box_tag('option_value_ids[]', brand.id, has_brand, id:"brand_checkbox_#{brand.id}" )
      concat image_tag(icon_path, alt: brand.presentation)
    end
  end

  ##
  # Rendering of rows of brand cards.
  # If to manually specify brands, provide @option_value_attribute w/ either :name or :presentation, 
  # so the given @brands values match those Spree::OptionValue#xxxx attribute.  This intends to 
  # ensure accuracy of found brands w/ same spellings.
  def make_brand_option_value_cards(option_value_attribute = :name, brands = nil, base_css_class = '')
    rows = []
    current_columns = []
    @brand_ot ||= Spree::OptionType.find_by(name:'brand')
    brands ||= Ioffer::Brand.not_created_by_users.all.collect{|b| b.send(option_value_attribute).downcase }
    option_values = @brand_ot.option_values.where(option_value_attribute => brands).all
    presentation_to_option_values = option_values.group_by{|ov| ov.send(option_value_attribute).downcase }

    brands.each_with_index do|b, index|
      option_value = presentation_to_option_values[b].try(:first)
      next if option_value.nil?
      current_columns << brand_option_value_card(option_value, base_css_class)
      if current_columns.size >= 5
        rows << content_tag(:div, class:'row') do
          current_columns.each do|col|
            concat col
          end
        end
        current_columns.clear
      end
    end
    # left over
    if current_columns.size > 0
      rows << content_tag(:div, class:'row') do
        current_columns.each do|col|
          concat col
        end
      end
      current_columns.clear
    end

    rows.each do|row|
      concat row
    end
  end
end
