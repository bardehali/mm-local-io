# Adjust thread count based on workload
threads_count = ENV.fetch('RAILS_MAX_THREADS') { 6 }
threads threads_count, threads_count

app_dir = File.expand_path('../../', __FILE__)
puts "app_dir: #{app_dir}"
shared_dir = "#{app_dir}/shared"

FileUtils.mkdir_p File.join(app_dir, 'shared/log')
FileUtils.mkdir_p File.join(app_dir, 'shared/pids')

socket_path = ENV['PUMA_SOCKET']
unless socket_path && socket_path.present?
  FileUtils.mkdir_p File.join(app_dir, 'shared/sockets')
  socket_path = "#{shared_dir}/sockets/puma.sock"
end

port ENV.fetch('PORT') { 8000 }

bind "unix://#{socket_path}"

stdout_redirect "#{shared_dir}/log/puma.stdout.log", "#{shared_dir}/log/puma.stderr.log", true

pidfile "#{shared_dir}/pids/puma#{ENV['RAILS_ENV']}.pid"
state_path "#{shared_dir}/pids/puma.state"

# Fully utilize all 8 vCPUs per VPS
workers ENV.fetch("WEB_CONCURRENCY") { 4 }

# Enable Copy-On-Write for memory efficiency
preload_app!

# Improve database & Redis connection handling
on_worker_boot do
  require 'active_record'
  ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(YAML.load_file("#{app_dir}/config/database.yml")[ENV['RAILS_ENV']])

  # Ensure Redis connections don't get forked
  if defined?(Redis)
    Redis.current = Redis.new(url: ENV['REDIS_URL'])
  end

  # If using Sidekiq, set up connections
  if defined?(Sidekiq)
    Sidekiq.configure_client do |config|
      config.redis = { url: ENV['REDIS_URL'], size: 5 }
    end
  end
end

# Allow puma to be restarted by `rails restart`
plugin :tmp_restart
