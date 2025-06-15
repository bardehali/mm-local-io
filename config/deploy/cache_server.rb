set :environment, 'staging'
set :rails_env, 'staging'

set :branch, ENV['BRANCH'] || 'master'

server '45.32.187.192', user: 'deploy', roles: %w{web app}

set :ssh_options, {
    user: 'deploy',
    keys: ['~/.ssh/tbdmarket', '~/.ssh/id_rsa'],
    forward_agent: true,
    auth_methods: %w(publickey)
}