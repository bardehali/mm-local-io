class SellerOnboardingMailer < ApplicationMailer

  def seller_onboarding_email
    @user = params[:user]
    @host = Rails.application.config.action_mailer.default_url_options[:host]

    mail(to: @user.email, subject:"[AD] #{@user.username}, you are missing sales!")
  end

end
