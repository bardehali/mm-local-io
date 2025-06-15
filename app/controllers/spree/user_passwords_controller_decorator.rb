module Spree::UserPasswordsControllerDecorator
  def self.prepended(base)
    base.include Spree::Core::ControllerHelpers::MoreCommon
    
    base.before_action :save_request, only: [:edit]
    base.skip_before_action :require_no_authentication if base.respond_to?(:require_no_authentication)
  end

  def new
    logger.debug "| current_store: #{current_store&.name}"
    super
  end

  protected

  def save_request
    unless @user
      @token_digest = Devise.token_generator.digest(Spree::User, :reset_password_token, params[:reset_password_token] )
      @user = Spree::User.find_by_reset_password_token(@token_digest)
    end
    log = RequestLog.save_request(request, user_id: @user.try(:id) || spree_current_user.try(:id), group_name:'show_reset_password')
    if params[:utm_campaign].present?
      cookies[:utm_campaign] = params[:utm_campaign]
      session[:reset_password_source] = 'email'
    end
    session[:sign_in_source] = 'reset_password'
  rescue Exception => e
    logger.warn "** RequestLog problem: #{e.inspect}"
  end
end

Spree::UserPasswordsController.prepend(Spree::UserPasswordsControllerDecorator) if Spree::UserPasswordsController.included_modules.exclude?(Spree::UserPasswordsController)