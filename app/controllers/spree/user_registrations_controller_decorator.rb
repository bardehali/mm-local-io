module Spree
  module UserRegistrationsControllerDecorator

    def self.prepended(base)
      base.include Spree::Core::ControllerHelpers::MoreCommon

      base.before_action :save_after_sign_up_data, only: [:new]
    end

    ##
    # Override of spree_auth_devise-4.3.4
    # Reason: send_confirmation_instructions called twice
    def create
      @user = build_resource(spree_user_params)

      logger.debug "Turnstile Response: #{params['cf-turnstile-response']}"

      # Check if 'verify=true' is present before proceeding with captcha verification
      #if params[:verify] == "true"
      if true
        captcha_verification = verify_turnstile_captcha(params['cf-turnstile-response'])

        unless captcha_verification['success']
          flash[:error] = "Captcha verification failed."
          redirect_to registration_path and return
        end
      else
        logger.debug "Skipping Turnstile verification as verify=true is not present."
      end

      logger.debug "| user valid? #{resource.valid?}: #{resource.errors.messages}"
      resource.skip_confirmation_notification! if Spree::Auth::Config[:confirmable]
      resource_saved = resource.save
      logger.debug "| resource #{resource.class} w/ params #{spree_user_params}"
      yield resource if block_given?
      if resource_saved
        if resource.active_for_authentication?
          set_flash_message :notice, :signed_up
          sign_up(resource_name, resource)
          session[:spree_user_signup] = true
          redirect_to_checkout_or_account_path(resource)
        else
          set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        logger.debug "| cannot register: #{@user.errors.messages}"
        logger.debug "| user #{@user.class} #{@user.attributes}"
        clean_up_passwords(resource)
        render :new
      end
    end


    private

    def verify_turnstile_captcha(token)

      logger.debug "| Turnstile verification token: #{token}"

      uri = URI.parse("https://challenges.cloudflare.com/turnstile/v0/siteverify")
      # request = Net::HTTP.post_form(uri, secret: "0x4AAAAAAAVkUO_FUeU0VPakFzDGwNr6x9U", response: token)
      request = Net::HTTP.post_form(uri, secret: "0x4AAAAAAAVkUO_FUeU0VPakFzDGwNr6x9U", response: token)
      response = JSON.parse(request.body)

      # Log for debugging, remove or adjust as needed
      logger.debug "| Turnstile verification response: #{response}"

      response
    end

    protected

    def after_sign_up_path_for(resource)
      session['spree_user_return_to'] || super(resource)
    end

    def save_after_sign_up_data
      session['spree_user_return_to'] = params[:return_to] if params[:return_to].present?
    end

    ##
    # Modded version
    def redirect_to_checkout_or_account_path(resource)
      resource_path = after_sign_up_path_for(resource)
      logger.info "| resource path #{resource_path} vs #{spree.checkout_state_path(:cart) } vs #{spree.checkout_path} (#{resource_path.starts_with?( spree.checkout_path )})"
      if resource_path && resource_path.starts_with?( spree.checkout_path )
        respond_with resource, location: resource_path
      else
        redirect_to after_sign_in_path_for(resource)
      end
    end
  end
end

Spree::UserRegistrationsController.prepend(Spree::UserRegistrationsControllerDecorator) if Spree::UserRegistrationsController.included_modules.exclude?(Spree::UserRegistrationsControllerDecorator)
