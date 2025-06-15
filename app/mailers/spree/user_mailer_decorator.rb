module Spree::UserMailerDecorator
  def self.prepended(base)
    base.include Spree::BaseMailerDecorator
    base.helper Spree::BaseMailerDecorator::HelperMethods
  end

  ##
  # Overrides of /spree_auth_devise-4.3.4/app/mailers/spree/user_mailer.rb

  def reset_password_instructions(user, token, *_args)
    @user = user
    m = super(user, token, *_args)
    check_to_apply_settings(m)
    m
  end

  def confirmation_instructions(user, token, _opts = {})
    @user = user
    m = super(user, token, _opts)
    check_to_apply_settings(m)
    m
  end

end

Spree::UserMailer.prepend(Spree::UserMailerDecorator) if Spree::OrderMailer.included_modules.exclude?(Spree::UserMailerDecorator)