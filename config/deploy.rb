# config valid for current version and patch releases of Capistrano
lock '~> 3.11.0'

set :rvm_type, :user
set :rvm_ruby_string, proc { `cat .ruby-version`.chomp }
set :rvm_ruby_version, proc { `cat .ruby-version`.chomp }

set :stages, %w(production staging development)
set :default_stage, 'staging'

domain = 'ioffer.com'
set :application, 'shoppn_spree'
set :repo_url, 'github-iofferdev:ioffer-dev/ioffer.git'

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

branch = ENV['BRANCH'] || `git symbolic-ref HEAD 2> /dev/null`.strip.gsub(/^refs\/heads\//, '')
puts '#' * 60
puts "# Deploying branch #{branch}"
set :branch, branch

ENV_TO_BASE_PATH_MAP = {
  staging: '/var/www/shoppn_spree',
  production: '/var/www/shoppn_spree',
}
ENV_TO_PORT_MAP = {
  staging: 3000,
  production: 8000
}
stage = fetch(:stage).to_sym
puts "stage: #{stage}"

base_path = ENV_TO_BASE_PATH_MAP.fetch(stage) { ENV_TO_BASE_PATH_MAP.fetch(:staging) }
puts "base_path: #{base_path}"
set :deploy_to, base_path

shared_path = base_path + '/shared'
current_path = base_path + '/current'
set :current_path, current_path

set :linked_files, %w{config/master.key config/credentials.yml.enc}


######################################

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
set :pty, true


# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
append :linked_dirs, 'shared/log', 'shared/pids', 'shared/sockets'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :user, 'deploy'
set :use_sudo, false

#######################################
# Puma server

set :puma_conf, "#{current_path}/config/puma.rb"
set :puma_bind,       "unix://#{shared_path}/sockets/puma.sock"
set :puma_state,      "#{shared_path}/pids/puma.state"
set :puma_pid,        "#{shared_path}/pids/puma.pid"
set :puma_access_log, "#{shared_path}/log/puma.error.log"
set :puma_error_log,  "#{shared_path}/log/puma.access.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, false  # Change to true if using ActiveRecord


#######################################
# Before and after

# after 'deploy', 'deploy:prepare_assets'

#######################################
# Extra actions

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/sockets -p"
      execute "mkdir #{shared_path}/pids -p"
      execute "mkdir #{shared_path}/log -p"
      execute "mkdir #{shared_path}/config -p"
      execute "mkdir #{shared_path}/storage -p"
      execute "mkdir #{shared_path}/cache -p"
      execute "mkdir #{shared_path}/pupscraper/node_modules -p"
      execute "mkdir #{shared_path}/public/uploads -p"
      execute "mkdir #{shared_path}/public/spree -p"
    end
  end

  desc 'Restart application by killing process of Puma and starting it'
  task :restart do
    on roles(:app), primary: true do|host|
      # invoke 'puma:restart'
      within "#{current_path}" do
        command = "source /home/deploy/.bash_profile && cd #{fetch(:deploy_to)}/current && kill -s QUIT $(cat #{current_path}/shared/pids/puma*.pid); bundle exec puma -C config/puma.rb --daemon"
        begin
          exec "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
        rescue Exception => e
          puts " .. could not kill puma process: ---------------------\n#{e}"
          puts '---------------------------------'
        end
        # somehow puma:start often fails
        execute 'bundle exec puma -C config/puma.rb --daemon'
      end
    end
  end

  before :deploy, 'puma:make_dirs'.to_sym
end

namespace :deploy do
  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end


  desc 'Link user uploads done via Spree engine to shared path'
  task :link_uploads do
    on roles(:web) do
      execute "mv #{current_path}/public/spree #{current_path}/public/spree.old"
      execute "ln -s #{shared_path}/public/spree #{current_path}/public/spree"
    end
  end

  desc 'Link storage path to use shared one'
  task :link_active_storage_directory do
    on roles(:web) do
      execute "mv #{current_path}/storage #{current_path}/storage.old"
      execute "ln -s #{shared_path}/storage #{current_path}/"
      execute "if test -f \"#{shared_path}/config/storage.yml\"; then cat #{shared_path}/config/storage.yml > #{current_path}/config/storage.yml; fi"
      execute "if test -f \"#{shared_path}/config/elasticsearch.yml\"; then cat #{shared_path}/config/elasticsearch.yml > #{current_path}/config/elasticsearch.yml; fi"
    end
  end

  desc 'Link log folder to shared path'
  task :link_log_directory do
    on roles(:web) do
      execute "mv #{current_path}/log #{current_path}/log.old"
      execute "ln -s #{shared_path}/log #{current_path}/"
    end
  end

  desc 'Link current/shared folder to shared path'
  task :link_shared_directory do
    on roles(:app) do
      execute "mv #{current_path}/shared #{current_path}/shared.old"
      execute "ln -s #{shared_path} #{current_path}/"
    end
  end

  desc 'Link current/tmp/cache folder to shared path'
  task :link_tmp_cache_directory do
    on roles(:app) do
      execute "mv #{current_path}/tmp/cache #{current_path}/tmp/cache.old"
      execute "ln -s #{shared_path}/cache #{current_path}/tmp/"
    end
  end

  desc 'Link current/script/nodejs/pupscraper/node_modules folder to shared/pupscraper/node_modules path'
  task :link_node_modules_directory do
    on roles(:app) do
      execute "ln -s #{shared_path}/pupscraper/node_modules #{current_path}/script/nodejs/pupscraper/"
      execute "cd #{current_path}/script/nodejs/pupscraper/"
      execute "npm install"
    end
  end

  desc 'Copy fonts to public/assets as workaround of font path problem'
  task :copy_fonts_to_assets do
    on roles(:web) do
      execute "cp -Rn #{current_path}/app/assets/fonts/* #{shared_path}/public/assets"
    end
  end

  # after  :finishing,    :compile_assets
  before :finishing, :link_shared_directory
  after  :finishing, :cleanup
  after  :finishing, :link_uploads
  after  :finishing, :link_log_directory
  after  :finishing, :link_active_storage_directory
  after  :finishing, :link_tmp_cache_directory
  after  :finishing, :link_node_modules_directory
  after  :finishing, :copy_fonts_to_assets
end

namespace :redis do
  desc 'Download source, decompress and compile'
  task :setup do
    on roles(:app) do
      execute 'mkdir -p /var/www/redis'
      within '/var/www/redis' do
        execute 'pwd'
        execute 'if [ ! -f ./redis-stable.tar.gz ]; then wget https://download.redis.io/releases/redis-stable.tar.gz --directory /var/www/redis; fi'
        execute 'tar xzf redis-stable.tar.gz --directory /var/www/redis/'
        execute 'cd /var/www/redis/redis-stable'
        execute 'make'
      end
    end
  end

  desc 'Ensure Redis is running'
  task :start do
    on roles(:app) do
      within '/var/www/redis/redis-stable' do
        result = capture 'ps ax | grep redis'
        if false && result =~ /\bredis\-server\s+\d+/
          puts 'Redis server already running'

        else
          puts 'Will run redis now'
          execute 'pwd'
          execute 'cd src'
          execute 'src/redis-server redis.conf'
        end
      end
    end
  end
end

task :env do
  on roles(:all) do
    execute 'env'
  end
end
