module Ioffer::CategoriesHelper
  # @which_category [Category or category.name]
  def category_card(which_category, icon_path, base_css_class = '')
    category = which_category.is_a?(Ioffer::Category) ? which_category : 
      @categories_map.try(:fetch, which_category){ Ioffer::Category.where(name: which_category) }.first
    return content_tag(:i) if category.nil?
    has_cat = current_user ?
      current_user.user_categories.collect(&:category_id).include?(category.id) : nil
    content_tag(:div, class:"col-sm category-card-wrapper categories #{base_css_class}#{' category-selected' if has_cat}", title: category.name, 'data-toggle'=>'tooltip' ) do
      concat check_box_tag('category_ids[]', category.id, has_cat, id:"category_checkbox_#{category.id}" )
      concat image_tag(icon_path, alt: category.name)
      concat content_tag(:div, class:'cat-label') { category.name }
    end
  end

  # @which_category [Spree::Taxon or category.name]
  def category_taxon_card(which_category, icon_path, base_css_class = '', query_conditions = {} )
    @categories_taxonomy ||= Spree::Taxonomy.categories_taxonomy
    if which_category.is_a?(Spree::Taxon) 
      category = which_category
      categories = [category]
    else
      categories = @categories_taxonomy.taxons.where(query_conditions.size > 0 ? query_conditions : 
        { name: which_category} ).all
      category = categories.first
    end
    return content_tag(:i) if category.nil?

    category_name = which_category.is_a?(Spree::Taxon) ? category.name : which_category

    logger.info "| #{category_name}, compare #{ ( (spree_current_user ? spree_current_user.user_selling_taxons.collect(&:taxon_id) : []) & categories.collect(&:id) ) }"
    has_cat = spree_current_user ?
      (spree_current_user.user_selling_taxons.collect(&:taxon_id) & categories.collect(&:id) ).present? : nil
    content_tag(:div, class:"col-sm category-card-wrapper categories #{base_css_class}#{' category-selected' if has_cat}", title: category.name, 'data-toggle'=>'tooltip' ) do
      categories.each_with_index do|cat, i|
        concat check_box_tag('taxon_ids[]', cat.id, has_cat, id:"category_checkbox_#{cat.id}" )
      end
      concat image_tag(icon_path, alt: category_name)
      concat content_tag(:div, class:'cat-label') { category_name }
    end
  end
end