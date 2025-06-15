module Admin
  module Servers
    class Manager
      attr_accessor :settings
      def initialize(config_file_path = File.join(Rails.root, 'config/servers_to_check.yml'))
        self.settings = YAML::load( File.open(config_file_path) )
      end

      def servers
        unless @servers
          @servers = []
          settings.each_pair do|hostname, h|
            @servers << Admin::Server.new(h.merge('hostname' => hostname) )
          end
        end
        @servers
      end
    end
  end
end