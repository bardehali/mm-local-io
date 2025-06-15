require File.join( File.dirname(__FILE__), 'process.rb')

module Admin
  module Servers
    class DelayedJob < Process
      def self.valid?(process)
        process[:command] =~ /\A\s*([a-z\/]+)?delayed_job\b/
      end

      def can_be_restarted?
        true
      end

      def self.start_process_command(process)
        "#{source_profile_command} && /var/www/shoppn_spree/current/bin/delayed_job start"
      end
      
    end
  end
end