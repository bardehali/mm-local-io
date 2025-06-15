##
# Methods to be implemented
module Admin
  module Servers
    class Process
      attr_accessor :attributes, :running

      delegate :[], to: :attributes

      def initialize(attr = {})
        self.attributes = attr
      end

      def command_name
        @command_name ||= self.class.find_main_command_name(attributes[:command])
      end

      def pid
        attributes[:pid]
      end

      def time
        attributes[:time]
      end

      def valid?
        self.class.valid?(self)
      end

      def logger
        self.class.logger
      end

      def can_be_restarted?
        false
      end

      ##
      # When needed to run things like bundler, bash initialization 
      # of RoR is needed.
      def source_profile_command
        'source /home/deploy/.bash_profile'
      end

      def kill_process_command
        self.class.kill_process_command(self)
      end

      def start_process_command
        self.class.start_process_command(self)
      end

      ################################
      # Class methods

      def self.logger
        ::Spree::User.logger
      end

      ##
      # General way to send SIGTERM to process ID
      # @process [Admin::Servers::Process]
      def self.kill_process_command(process)
        process.pid ? 'kill -s SIGTERM #{process.pid}' : "echo 'No need to kill process'"
      end

      def self.start_process_command(process)
        logger.info "** #{process} start_process not implemented"
      end

      ##
      # @process [Admin::Servers::Process]
      def self.find_process(processes = [])
        processes.find{|p| valid?(p) }
      end

      def self.valid?(process)
        false
      end
  
      def self.running?(processes = nil)
        !find_process(processes).nil?
      end

      ##
      # @return [appropriate subclass of Process w/ attributes]
      def self.build(process_attributes = {})
        klass = find_class_of_process(process_attributes)
        klass.new(process_attributes)
      rescue Exception
        nil
      end

      ##
      # @command_or_process_attributes [String or Hash]
      def self.find_class_of_process(command_or_process_attributes = {})
        command_name = command_or_process_attributes.is_a?(String) ? 
          command_or_process_attributes : find_main_command_name(command_or_process_attributes[:command] )
        ( 'Admin::Servers::' + command_name.titleize.gsub(' ', '') ).constantize
      rescue NameError
        nil
      end

      ##
      # @command [String] command w/ arguments
      def self.find_main_command_name(command)
        args = command.split(/[\s\:]+/)
        args.pop if args.last == '-d'
        if args.first.ends_with?('java') # calls in syntax "java -Xmsg org.elasticsearch.bootstrap.Elasticsearch -d"
          args.last.split('.').last&.strip
        elsif args.first =~ /\b(mysql|redis)(d|\-server)/ # those that might have daemon process
          $1
        else
          args.first&.strip
        end
      end

      def self.is_valid_process?(process_command)
        false
      end
      
    end
  end
end