module Ioffer
  class BaseGenerator
    ##
    # @settings
    #   :dry_run [Boolean]
    #   :user_list_name or :user_list [String] default 'generated_users'; name of Spree::UserList
    def initialize(settings = {})

      self.settings = normalize_settings(settings)
    end

    def user_list
      @user_list ||= settings[:user_list_id] ? Spree::UserList.find_by(id: settings[:user_list_id]) : nil
      unless @user_list
        m = settings[:dry_run]==true ? :find_or_initialize_by : :find_or_create_by
        @user_list = Spree::UserList.send(m, { name: user_list_name } )
      end
      @user_list
    end

    def user_list_name
      settings[:user_list_name] || settings[:user_list]
    end

    def logger
      Spree::User.logger
    end

    protected

    def normalize_settings(settings)
      settings.slice(:user_list_id, :user_list_name, :user_list, :dry_run)
    end
  end
end