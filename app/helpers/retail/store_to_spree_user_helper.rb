module Retail
  module StoreToSpreeUserHelper
    def retail_site_store_id_placeholder(retail_site, prefix = 'Enter ')
      label = ( I18n.t("retail_sites.input_placeholder.#{retail_site.name_normalized}") || 
        I18n.t("retail_sites.input_placeholder.default") ) % [retail_site.name]
      prefix + label
    end

    def retail_store_input_label(retail_site)
      ::Retail::Store.make_store_url(retail_site.name, '').gsub(/((https:\/\/)?www\.)/, '')
    end
  end
end