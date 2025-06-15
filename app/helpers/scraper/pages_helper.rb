module Scraper::PagesHelper

  PAGE_TYPE_TO_GLYPHICON_SUBCLASS = {
    'landing' => 'home', 'index' => 'list', 'store' => 'shopping-cart', 'detail' => 'modal-window'
  }

  # Font-awesome icon CSS class
  def page_type_icon_css_class(page_type)
    'glyphicon glyphicon-' + PAGE_TYPE_TO_GLYPHICON_SUBCLASS[page_type].to_s
  end

  def previous_page_of(current_page)
    current_page.retail_site.pages.where('id < ?', current_page.id).order('id desc').limit(1).first
  end

  def next_page_of(current_page)
    current_page.retail_site.pages.where('id > ?', current_page.id).order('id asc').limit(1).first
  end

  ##
  # Strip away html, body tags, and script section
  def strip_page_source(source)
    s = source.clone
    s.gsub! /(<\/?html>)/, ''
    s.gsub! /(<\/?body>)/, ''
    s.gsub! /(<script[^>]*>.*<\/script>)/, ''
    s
  end

  def shortened_ending_path(path)
    parts = path.split('/')
    parts[parts.size - 3, parts.size].join('/')
  end
end
