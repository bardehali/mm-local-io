module Spree
  module Core
    module ControllerHelpers
      module MoreCommon
        extend ActiveSupport::Concern

        included do
          helper_method :default_title
          helper_method :accurate_title
          helper_method :current_store
        end

        ##
        # Common helper methods
        def default_title
          I18n.t('site_name')
        end
      
        # this is a hook for subclasses to provide title
        def accurate_title
          default_title.gsub(/(\W+)/, '-')
        end

        def current_store
          @current_store = Rails.cache.fetch('current_store'){ Spree::Store.default }
        end

      end
    end
  end
end