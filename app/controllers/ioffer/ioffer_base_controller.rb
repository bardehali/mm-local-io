class Ioffer::IofferBaseController < ApplicationController

  layout 'ioffer_application'

  include Spree::Core::Engine.routes.url_helpers
  helper Spree::Core::Engine.routes.url_helpers
  helper ControllerHelpers::GeoFence # methods like find_country

  before_action :assign_client_id

  protected

  def not_signed_in_path
    new_ioffer_user_path(t: Time.now.to_i)
  end

  ##
  # Must be signed in to check
  def check_signed_in_user
    if current_user.nil?
      params.permit(:auto_login_token, :user)
      if params[:auto_login_token].present? && (auto_login_user = Ioffer::User.where(auto_login_token: params[:auto_login_token] ).first )
        logger.info " -> auto login user (#{auto_login_user.id})"
        log_in(auto_login_user)
        redirect_to '/payments'
      elsif spree_current_user.nil?
        redirect_to not_signed_in_path
      end

    else
      if spree_current_user.nil?
        sign_in(:spree_user, current_user.convert_to_spree_user!)
      end
    end
  end
end