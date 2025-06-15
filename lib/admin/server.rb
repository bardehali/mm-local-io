##
# Container for checking for specific processes running, such as 
# puma, mysql.  Also includes server load such as stats shown in uptime command.
module Admin
  class Server
    attr_accessor :configuration, :user, :host

    ##
    # @config keys in string
    def initialize(config = {})
      self.user = config['user'] || 'deploy'
      self.host = config['host'] || '127.0.0.1'
      self.configuration = config
    end

    ###############################
    # Global methods

    UPTIME_TIME_AND_UP_TIME_REGEXP = /\b([\d:]+)\s+\bup\s+([\d:]+)/i
    UPTIME_COUNT_OF_USERS_REGEXP = /\b(\d+)\s+users?\b/i
    UPTIME_LOAD_AVERAGES_REGEXP = /\bload\s+averages?:?\s*([\d\.]+)(,?\s+([\d\.]+))?(,?\s+([\d\.]+))?/i
    ##
    # Use of uptime command given response like:
    #   10:23  up 10:21, 9 users, load averages: 3.48 2.62 2.30
    # @return [Hash w/ keys :current_time, :running_time, :count_of_users, 
    #   :load_over_1_minute, :load_over_5_minutes, :load_over_15_minutes]
    def load_stats(force_to_run = false)
      return @load_stats if @load_stats && !force_to_run

      response = `#{command_prefix}uptime`
      @load_stats = {}
      if (m = response.match(UPTIME_TIME_AND_UP_TIME_REGEXP))
        @load_stats[:current_time] = m[1]
        @load_stats[:running_time] = m[2]
      end
      if (m = response.match(UPTIME_COUNT_OF_USERS_REGEXP))
        @load_stats[:count_of_users] = m[1].to_i
      end
      if (m = response.match(UPTIME_LOAD_AVERAGES_REGEXP))
        @load_stats[:load_over_1_minute] = m[1].to_f
        @load_stats[:load_over_5_minutes] = m[3].to_f if m[3]
        @load_stats[:load_over_15_minutes] = m[5].to_f if m[5]
      end
      @load_stats
    end

    def hostname
      @hostname ||= host == '127.0.0.1' ? 'localhost' : ( configuration['hostname'] || `hostname`.strip )
    end

    def current_load
      h = load_stats
      h[:load_over_15_minutes] || h[:load_over_5_minutes] || h[:load_over_1_minute] || h[:load]
    end

    ##
    # @grep_filter_argument [String] if exist, output of @find_all_passesses_command 
    # would be directed to grep.
    # @return [Array of Admin::Servers::Process]
    def find_all_processes(grep_filter_argument = nil, force_to_run = false)
      @cache_of_proccesses ||= {}
      processes = @cache_of_proccesses[grep_filter_argument]
      return processes if processes && !force_to_run

      command = find_all_processes_command
      command << ' | ' + grep_filter_command(grep_filter_argument) if grep_filter_argument.present?
      lines = `#{command_prefix}#{command}`.lines
      lines.delete_if{|line| line.index('grep ')} if grep_filter_argument.present?
      processes = []
      parse_ps_lines( lines ) do|attr|
        p = Admin::Servers::Process.build(attr)
        # /mysql|elasticsearch|redis|puma|delayed/
        processes << p if p
      end
      @cache_of_proccesses[grep_filter_argument] = processes
      processes
    end

    # General run of @command in remote server.
    def run_command(command)
      command_prefix.present? ? `#{command_prefix}\"#{command}\"` : `#{command}`
    end

    def running?(process_name)
      Admin::Servers::Process.find_class_of_process(process_name).running?
    rescue Exception => command_e
      Spree::User.logger.info "** #{command_e}"
      false
    end

    ##
    # Depending on configuration['running'], the process names to check running.
    # @return [Array of Admin::Servers::Process] w/ running attribute
    def running_proccesses
      found_proccesses = find_all_processes || []
      ps = configuration['running'].to_a.collect do|process_name|
        klass = Admin::Servers::Process.find_class_of_process(process_name)
        klass ||= Admin::Servers::Process

        found_instance = found_proccesses.find{|p| p.is_a?(klass) }
        found_instance.running = true if found_instance
        found_instance ? found_instance : klass.new(command: process_name)
      end
      ps
    end

    protected

    def command_prefix
      %w(localhost 127.0.0.1).include?(host) ? '' : "ssh #{user}@#{host} "
    end

    def find_all_processes_command
      'ps aux'
    end

    ##
    # Based on https://stackoverflow.com/questions/61858845/parse-ps-aux-linux-terminal-output-with-ruby.
    # @return [Array of Hash] each hash having process's pairs of attribute => value
    def parse_ps_lines(lines, headers = nil, &block)
      unless headers
        header_line = (lines.first =~ /\bPID\b/) ? lines.shift : `#{find_all_processes_command} | grep PID`.lines.first
        headers = header_line.split(/\s+/).map{|h| h.tr('%', '').downcase.intern }
      end
      lines.map do |line|
        next if line.index('fsevent_watch')
        # creates a hash from an array of pairs
        h = Hash[headers.zip(line.strip.split(/\s+/, headers.size))]
        yield h if block_given?
        h
      end
    end

    ##
    # @grep_argument [String] argument for grep command, the pattern to match
    def grep_filter_command(grep_argument)
      "grep \"#{grep_argument}\""
    end

  end
end