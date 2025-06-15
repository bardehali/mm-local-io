class AdvertiserMailer < ApplicationMailer

  def advertiser_login_list
    @user = params[:user]
    raw, enc = Devise.token_generator.generate(@user.class, :reset_password_token)
    @user.reset_password_token   = enc
    @user.reset_password_sent_at = Time.now.utc
    @user.save

    @host = Rails.application.config.action_mailer.default_url_options[:host]
    @url = URI.join( @host, Spree::Core::Engine.routes.url_helpers.edit_spree_user_password_path(reset_password_token: raw, utm_campaign: 'ioffer_102120', utm_medium: 'email', utm_source:'logo', utm_term: 'sign_in_post' ) )

    mail(to: @user.email, subject:"#{@user.username}, Jumpstart Your iOffer Store")
  end

end
