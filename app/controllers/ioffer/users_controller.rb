module Ioffer
  class UsersController < IofferBaseController

    include ControllerHelpers::SellerManager

    before_action :permit_params, only: [:update, :create]
    before_action :fetch_and_set_user, only: [:new, :update, :create]

    before_action :check_signed_in_user, only: [:getting_started]

    def new
      params.permit!
      @page_title = "#{t('site_name')} - Start Selling Now!"
      @user.update_attributes(last_visit_at: Time.now, visit_from_source: params[:visit_from_source] || params[:source]) if @user && @user.id

    end

    def seller_onboarding
      @page_title = 'iOffer - Welcome to the new iOffer'
      session['spree_user_return_to'] = ioffer_seller_getting_started_path
    end

    def getting_started
      @page_title = 'iOffer - Get started selling now!'
      load_store_data
    end

    def update
      if @user.save
        logger.debug "| saved and signing in #{@user.attributes}"

        log_in(@user)
        redirect_to after_save_path
      else
        logger.info "Errors: #{@user.errors.full_messages}"
        render 'home/index'
      end
    end

    def create
      stay_on_page = 'ioffer/users/new'
      if @user.errors.size == 0
        if !need_to_captcha_verify? || verify_recaptcha(model: @user)
          if @user.save
            logger.info "| saved and signing in #{@user.attributes}"
            @user.update_column(:reset_password_token, '')
            log_in(@user, false)

            @spree_user = @user.convert!
            if params[:buyer].nil?
              @spree_user.create_roles!
            end
            @spree_user.send_confirmation_instructions(Spree::Store.default) if Spree::Auth::Config[:confirmable]

            logger.info "| converted to Spree::User #{@spree_user}, seller? #{@spree_user.seller?}"
            sign_in(@spree_user)

            stay_on_page = nil
          else
            logger.info "| could not save: #{@user.errors}"
          end
        else
          @user.errors.add(:captcha_verified, 'Please verify that you are not a robot')
        end
      end
      if stay_on_page.present?
        logger.info "Errors: #{@user.errors.full_messages}"
        render stay_on_page
      else
        redirect_to after_save_path
      end
    end

    def logout
      log_out
      redirect_to '/'
    end

    ##
    # Mainly for test, going to the same after registration page as create action.
    def next_after_save
      redirect_to after_save_path
    end

    private

    def permit_params
      params.require(:user).permit(Ioffer::User::PERMITTED)
    end

    def fetch_and_set_user
      params.permit!
      user_params = params[:user] || params
      existing_user = nil
      if user_params
        # NULL reset_password_token could mean already claimed account. So nil or blank param could bypass.
        given_username = user_params[:username].to_s.strip
        if given_username.present? && user_params[:reset_password_token].present?
          existing_user = ::Ioffer::User.not_claimed.where(username: given_username, reset_password_token: user_params[:reset_password_token] ).first
        elsif user_params[:email].present?
          existing_user = ::Ioffer::User.where(
              given_username.present? ? user_params.slice(:username, :email) : user_params.slice(:email)
            ).first
        end
      end
      logger.debug "| existing_user? #{existing_user}" if existing_user
       @user = Ioffer::User.new(username: user_params[:username], reset_password_token: user_params[:reset_password_token], email: user_params[:email])
      if @user.new_record?
        @user.email = user_params[:email] if user_params[:email].present?
        @user.password = user_params[:password]
        @user.password_confirmation = user_params[:password_confirmation]
        set_user_info_to_model(@user)
      end
      logger.info "User valid? #{@user.valid?} errors? #{@user.errors.messages}" if @user.errors.size > 0
    end

    def not_signed_in_path
      login_path
    end

    def after_save_path
      ip = find_ip
      logger.debug "| after users save: IP #{ip} in #{find_country(ip)}: #{request.method} #{request.path} =>  accepted_location? #{accepted_location?(ip) }, accept_for_buyer? #{accepted_location_for_buyer?(ip) }"

      accepted_location? ? seller_contact_info_path : ioffer_payments_path
    end
  end
end
