# config/web3.rb

# Set the deployment environment
set :environment, 'production'
set :rails_env, 'production'

# Set the branch to deploy from
set :branch, ENV['BRANCH'] || 'master'

# Define the server and roles
server '83.229.82.155', user: 'deploy', roles: %w{web app db}, primary: true

# SSH options
set :ssh_options, {
  user: 'deploy',  # overrides user setting above
  keys: ['~/.ssh/tbdmarket', '~/.ssh/id_rsa'],  # specify the correct private key file
  forward_agent: true,
  auth_methods: %w(publickey)
}
