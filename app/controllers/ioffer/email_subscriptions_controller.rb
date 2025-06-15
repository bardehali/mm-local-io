class Ioffer::EmailSubscriptionsController < Ioffer::IofferBaseController
  
  skip_before_action :verify_authenticity_token
  skip_before_action :scan_user_through_geo_fence

  def create
    params.require(:email_subscription).permit(:email, :user_id, :is_seller)
    email = params[:email_subscription].try(:[], :email)
    logger.debug "| email: #{email}"
    render_path = nil # whether have render page w/ error
    if email.present?
      @email_subscription = Ioffer::EmailSubscription.find_or_initialize_by(email: email)
      @email_subscription.user_id = current_user.try(:id)
      @email_subscription.is_seller = params[:email_subscription].try(:[], :is_seller) || false
      set_user_info_to_model(@email_subscription)

      if need_to_captcha_verify?
        if verify_recaptcha(model: @email_subscription)
          @email_subscription.captcha_verified = true
          @email_subscription.save
        else
          logger.info "-> not captcha_verified, is_seller #{@email_subscription.is_seller?}, sub.id #{@email_subscription.id}"
          @email_subscription.errors.add(:captcha_verified, 'Please verify that you are not a robot')
          if @email_subscription.id
            render_path = nil
          else
            render_path = @email_subscription.is_seller ? 'ioffer/users/new' : 'home/index'
          end
        end
      else
        @email_subscription.save
      end
    end
    respond_to do|format|
      format.js
      format.html { render_path.present? ? render(render_path) : redirect_to( "/?t=#{Time.now.to_i}" ) }
    end
  end
end
