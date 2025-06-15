module TaskHelper
  ##
  # Iterates over arguments look for value in list of command line arguments like "max_pages=1 force".
  # Ensure that the value side of the argument variables (1 in max_pages=1) do not have = to confuse.
  def fetch_argument(args, argument_key, default_value = nil)
    pair = args.find{|a| a.index("#{argument_key}=") }
    pair.try(:split, '=').try(:last) || default_value
  end

  def trap_signal_and_exit
    Signal.trap('TERM') { cleanup_and_exit }
    Signal.trap('QUIT') { cleanup_and_exit }
    Signal.trap('INT') { cleanup_and_exit }
  end

  def cleanup_and_exit
    puts ' .. exiting'
    exit!(0)
  end

  def confirm_to_exit(message = nil)
    $stdout.write (message || '** Interrupted: stop the script?') + ' y/n or Ctrl+C > '
    confirm_to_exit = $stdin.gets.chomp
    if confirm_to_exit == 'y' || confirm_to_exit == 'Y'
      exit!(0)
    end
  rescue Interrupt
    cleanup_and_exit
  end
  
  def convert_env_variables
    @max_rows ||= ENV['MAX_ROWS']
    @limit ||= ENV['LIMIT'].to_i
    @offset ||= ENV['OFFSET'].to_i
    @extra_where ||= ENV['EXTRA_WHERE']
    @order ||= ENV['ORDER']
    @debug ||= (ENV['DEBUG'].to_s == 'true' )
    @dry_run ||= ( ENV['DRY_RUN'].to_s == 'true' )
  end

  ##
  # Depending on converted variable @dry_run.  If true, 
  # would not yield to run codes inside block
  def run_unless_dry_run(&block)
    yield if block_given? && !@dry_run
  end

  ##
  # Print some setting info.
  # Sets @start_time instance variable.
  def print_beginning_info(io = $stdout)
    @start_time = Time.now
    io.puts "========================================= #{@start_time.to_s}"
    io.puts "dry run? #{@dry_run}, debug? #{@debug}"
    io.puts "max_rows #{@max_rows}"
  end

  def print_ending_info(io = $stdout)
    puts "========================================\nFinished at #{Time.now.to_s}"
    if @start_time.is_a?(Time)
      puts "Took #{(Time.now - @start_time) / 1.second} secs (#{(Time.now - @start_time) / 1.minute} min)"
    end
  end

  ##
  # Depends on environment variables: MAX_ROWS or LIMIT, OFFSET
  def apply_more_to_query(query)
    convert_env_variables
    query = query.limit(@limit) if @limit > 0
    query = query.offset(@offset) if @offset > 0
    query = query.where(@extra_where) if @extra_where.present?
    query = query.order(@order) if @order.present?
    query
  end

  def sleep_when(index, every_one_delay = nil, every_how_many = nil, every_how_many_delay = nil)
    sleep_by_type(every_one_delay)
    sleep_by_type(every_how_many_delay) if every_how_many && index % every_how_many == 0
  end

  # @duration [either Range or Integer/Number]
  def sleep_by_type(duration = nil)
    if duration
      if duration.is_a?(Range)
        sleep(duration.min + rand(duration.max - duration.min))
      else
        sleep(duration)
      end
    end
  end

  ##
  # Based on arguments ARGV
  # @return [IO] either file or standard output.
  def find_or_default_output(is_default_stdout = true)
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    output_file = ARGV.shift
    output = if output_file.present?
      output_file = File.join(Rails.root, 'shared/data/', output_file) if output_file.index('/').nil?
      File.open( output_file, 'w')
    else
      is_default_stdout ? $stdout :nil
    end
    output
  end

  def logger
    Spree::Role.logger
  end
end