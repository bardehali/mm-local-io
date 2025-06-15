require File.join( File.dirname(__FILE__), 'process.rb')

module Admin
  module Servers
    class Nginx < Process
      ##
      # Nginx might have thread instances, so master one matters.
      def self.find_process(processes = [])
        ps = processes.find_all{|attr| p[:command] =~ /\Anginx\b/ }
        ps.find{|attr| p[:command] =~ /\Anginx\:?\s*\bmaster/ }
      end

    end
  end
end