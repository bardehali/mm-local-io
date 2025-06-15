class SellerOnboardingMailerAlternative < ApplicationMailer

  def seller_onboarding_email_alternative
    @user = params[:user]
    @host = Rails.application.config.action_mailer.default_url_options[:host]

    mail(to: @user.email, subject:"#{@user.username}, 数百万海外买家渴望光临您的店铺")
  end

end
