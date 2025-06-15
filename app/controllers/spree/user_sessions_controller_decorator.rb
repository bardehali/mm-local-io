module Spree::UserSessionsControllerDecorator

  def self.prepended(base)
    base.include Spree::Core::ControllerHelpers::MoreCommon
    
    base.helper_method :default_title
    base.helper_method :accurate_title
    base.before_action :permit_more_params
    base.after_action :sign_out_other_things, only: [:destroy]

    base.skip_before_action :verify_authenticity_token, :only => [:create]
  end

  def sign_in_as
    @user = Spree::User.find_by_id(params[:id]) || Spree::User.find_by_user_name(params[:user_name])
    if @user && can?(:sign_in_as, @user)
      sign_in_as_original_id = spree_current_user&.id
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
      logger.info "| signing in as #{@user.login} (#{@user.id})"

      old_times = @user.attributes.slice('last_active_at', 'current_sign_in_at', 'current_sign_in_ip', 'last_sign_in_at', 'last_sign_in_ip', 'sign_in_count')
      # logger.debug "| will keep old times: #{old_times}"

      sign_in(:spree_user, @user)

      # Not real user sign in, so keep old times
      @user.update_columns(old_times)
      session[:sign_in_as_original_id] = sign_in_as_original_id if sign_in_as_original_id

      respond_to do |format|
        format.html { redirect_to after_sign_in_path_for(resource) }
        format.json { render json: extra_user_json_hash }
      end

    else
      if @user.nil?
        flash[:error] = t('devise.registrations.user_not_found')
      elsif not can?(:sign_in_as, @user)
        flash[:error] = t("devise.registrations.no_permission")
      end
      respond_to do|format|
        format.json { render :json => {success: false, message:flash[:error] }, :status => 200 }
        format.html { redirect_to new_user_session_path }
      end
    end
  end

  protected

  
  ##
  # MoreCommon helper methods. Just cannot include or extend that module's method into 
  # this class.
  def default_title
    I18n.t('site_name')
  end

  # this is a hook for subclasses to provide title
  def accurate_title
    default_title.gsub(/(\W+)/, '-')
  end

  def after_sign_in_redirect(resource)
    if (return_to = session['spree_user_return_to'] ).present?
      session['spree_user_return_to'] = nil
      return_to
    else
      after_sign_in_path_for(resource)
    end
  end

  ##
  # Session data such as ioffer user needs to be cleared out also.
  def sign_out_other_things
    session[:signed_in_user_id] = nil
    session[:signed_in_user] = nil
    session[ControllerHelpers::GeoFence::PASSED_SESSION_KEY] = nil
  end

  def permit_more_params
    params.permit!
  end
end

Spree::UserSessionsController.prepend(Spree::UserSessionsControllerDecorator) if Spree::UserSessionsController.included_modules.exclude?(Spree::UserSessionsControllerDecorator)