require File.join( File.dirname(__FILE__), 'process.rb')

module Admin
  module Servers
    class Elasticsearch < Process
      def can_be_restarted?
        true
      end

      def self.valid?(process)
        process[:command] =~ /\bjava\s+/ && process[:command] =~ /\borg\.elasticsearch\b/
      end

      def self.start_process_command(process)
        'cd /var/www/elasticsearch* && bin/elasticsearch -d'
      end
    end
  end
end