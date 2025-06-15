require File.join(Rails.root, 'app/models/spree/user_decorator')

Recaptcha.configure do |config|
  config.site_key  = SystemSetting.settings['RECAPTCHA_SITE_KEY'] || ENV['RECAPTCHA_SITE_KEY'] || '6LepkvwUAAAAAGHYKlkUlplddlQ0eiI5RnUSsfb_'
  config.secret_key = SystemSetting.settings['RECAPTCHA_SECRET_KEY'] || ENV['RECAPTCHA_SECRET_KEY'] || '6LepkvwUAAAAACBsy2Nh6bmEJpbvR9aN0foIoFzv'
end

module Recaptcha
  EXCLUDED_COUNTRIES = Set.new( Spree::UserDecorator::ACCEPTED_COUNTRIES_FOR_FULL_SELLER )
end