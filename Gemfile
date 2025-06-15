source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.8'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.3'
# Use mysql as the database for Active Record
#gem 'mysql2', '>= 0.4.4'
gem 'mysql2', '~> 0.5.4'

gem 'seed_dump', '~> 3.3'

gem 'maxmind-geoip2'
group :production do
  gem 'newrelic_rpm', '~> 8.15'
end
gem 'rack-attack'

# Use Puma as the app server
gem 'puma', '~> 4.3'
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 4.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.4'
gem 'redis-activesupport'
gem 'redis-namespace'
gem 'redis-rails'

# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Use Capistrano for deployment
gem 'capistrano', '3.11.0'
gem 'rvm-capistrano', '~> 1.5.0'

group :development, :staging do
  gem 'ed25519'
  gem 'bcrypt_pbkdf'
  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano3-puma'
end

############################################
# Backend

gem 'active_model-unvalidate'

############################################
# Frontend

gem 'inherited_resources', '~> 1.11'
gem 'haml', '~> 5.1.0'
gem 'browser'

# Reduces boot times through caching; required in config/boot.rb
# gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

############################################
# Assets

gem 'fog-core', '~> 2.1'
gem 'fog-json', '~> 1.1'
gem 'fog-xml'
gem 'fog-aws', '~> 3.12'
gem 'carrierwave_direct'
gem 'rmagick', '~> 3.1'
gem 'carrierwave', '~> 1.3'

group :development, :test, :staging do
  gem 'webp-ffi', '0.3.1'
end

gem 'chartkick', '~> 4.1'

##########################################
# Search

gem 'elasticsearch', '~> 7.13.0'
gem 'elasticsearch-api', '~> 7.13.0'
gem 'elasticsearch-model', '~> 7.1'
gem 'elasticsearch-rails', '~> 7.1'


##########################################
# Market

gem 'spree', '~> 4.1.14'
gem 'spree_backend', '~> 4.1.14'
gem 'spree_frontend', '~> 4.1.14'
gem 'spree_auth_devise', '~> 4.1'
gem 'spree_gateway', '~> 3.7'
# gem 'spree_multi_vendor', github: 'spree-contrib/spree_multi_vendor'

##########################################
# Order

gem 'paypal-checkout-sdk'


gem 'spree_reviews', github: 'spree-contrib/spree_reviews'

##########################################
# User

gem 'recaptcha', require: 'recaptcha/rails'

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '~> 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'spring-commands-rspec', '~> 1.0'
end

group :test do
  gem 'rspec'
  gem 'rspec-rails'
  #gem 'rspec-solr'
  gem 'rspec_junit_formatter'

  gem 'factory_bot'
  gem 'factory_bot_rails'
end

group :development, :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'capybara-mechanize'

  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers', '~> 4.4'

  gem 'pry'
  gem 'pry-nav'
  gem 'pry-rails'
  gem 'pry-stack_explorer'

  # gem 'webrat'

  # gem 'rails_best_practices'

end

gem 'geocoder'

# Scraping
gem 'geo_ip'
gem 'mechanize'
gem 'nokogiri', '~> 1.10'

gem 'stemmer'
gem 'countries'


# Background
gem 'delayed_job', '~> 4.1'
gem 'delayed_job_active_record', '~> 4.1'
gem 'daemons', '~> 1.3'

# Storage
gem 'aliyun-sdk', '~> 0.8'
