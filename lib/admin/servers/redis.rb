require File.join( File.dirname(__FILE__), 'process.rb')

module Admin
  module Servers
    class Redis < Process
      def self.valid?(process)
        # syntax: redis-server 127.0.0.1:6379
        process[:command] =~ /\Aredis\-server\b.+:6379/
      end
    end
  end
end