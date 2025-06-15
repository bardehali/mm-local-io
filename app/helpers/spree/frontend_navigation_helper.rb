module Spree::FrontendNavigationHelper

  ##
  # Replacement that of Spree::NavigationHelper#spree_nav_cache_key
  def nav_cache_key(section = 'header')
    @nav_cache_key = begin
      keys = base_cache_key + [current_store, spree_navigation_data_cache_key, Spree::Config[:logo], stores&.cache_key, section, user_group]
      Digest::MD5.hexdigest(keys.join('-'))
    end
  end
end