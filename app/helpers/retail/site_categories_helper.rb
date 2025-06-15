module Retail::SiteCategoriesHelper

  ##
  # @cat <SiteCategory>
  def list_item_for_mapping(cat, list_item_html_options = {})
    icon_subclass = cat.mapped_taxon_id ? 'check' : 'align-justify' # menu-hamburger not there
    css_class = list_item_html_options.fetch(:class, '') + " taxon-level-#{cat.level}"
    content_tag :div, list_item_html_options.merge(class: css_class) do
      concat link_to(cat.name, '#', target:'_blank', title:'Check products in this category','data-toggle'=>'tooltip')
      concat '&nbsp;&nbsp;'.html_safe
      concat (
        content_tag :span, class:'actions' do
           link_to(retail_site_category_path(cat, format:'js'), remote: true, title:'Click to set mapping', 'data-toggle'=>'tooltip', class:'taxon-mapping-button' ) do
             content_tag('i', id: "map_site_category_button_#{cat.id}", class: 'icon icon-' + icon_subclass) { }
           end
         end
        )
    end
  end

end