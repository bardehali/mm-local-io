##
# Only works for local

module ServerHelper
  def graceful_restart_puma
    `bundle exec pumactl -P shared/pids/pumastaging.pid restart`
  end

  def fresh_start_puma(daemon = true)
    daemon_s = daemon ? ' --daemon' : ''
    `bundle exec puma -C config/puma.rb#{daemon_s}`
  end

  ##
  # Memory in MB.
  def memory_stats
    output = `vmstat`
    lines = output.split("\n")
    values = lines.last.split(/\s+/)
    stats = {}
    lines[-2].split(/\s+/ ).each_with_index do|header, index|
      stats[header.strip] = values[index].to_i
    end
    stats
  end

  def available_memory
    # linux
    memory_stats['free']
  rescue Exception => e
  end
end