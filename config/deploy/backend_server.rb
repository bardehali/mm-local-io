set :environment, 'production'
set :rails_env, 'production'

set :branch, ENV['BRANCH'] || 'master'

server '45.32.187.246', user: 'deploy', roles: %w{web app db}

set :ssh_options, {
    user: 'deploy',
    keys: ['~/.ssh/tbdmarket', '~/.ssh/id_rsa'],
    forward_agent: true,
    auth_methods: %w(publickey)
}