require File.join( File.dirname(__FILE__), 'process.rb')

module Admin
  module Servers
    class Mysql < Process
      # Syntax: /usr/sbin/mysqld --daemonize --pid-file=/run/mysqld/mysqld.pid
      def self.valid?(process)
        process[:command] =~ /\A\s*([a-z\/]+)?mysqld?\b/
      end
    end
  end
end