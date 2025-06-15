require File.join( File.dirname(__FILE__), 'process.rb')

module Admin
  module Servers
    class Puma < Process
      def self.valid?(process)
        process[:command] =~ /\Apuma\s+4/
      end

      def can_be_restarted?
        true
      end

      def self.kill_process_command(process)
        "kill -s QUIT #{process.pid ? process.pid : '$(cat /var/www/shoppn_spree/current/shared/pids/puma*.pid);'}"
      end

      def self.start_process_command(process)
        "#{source_profile_command} && cd /var/www/shoppn_spree/current && bundle exec puma -C config/puma.rb --daemon"
      end
    end
  end
end