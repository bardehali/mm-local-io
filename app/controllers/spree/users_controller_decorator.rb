module Spree::UsersControllerDecorator
  def self.prepended(base)
    base.include Spree::Admin::Shared::AdoptionHelper
    base.include User::MessagesHelper

    # base.before_action :check_for_seller_account, only: [:show, :account]
    base.skip_before_action :set_current_order, only: [:onboarding, :onboarding_change_password]
    base.skip_before_action :scan_user_through_geo_fence, except: [:account] unless Rails.env.test? 

    base.before_action :load_user, only: [:onboarding, :onboarding_change_password]
  end

  def account
    @page_title = I18n.t('spree.account')
    @user = spree_current_user || try_spree_current_user
    if @user&.seller?
      redirect_to admin_products_path
    elsif @user&.buyer?
      params[:q] ||= {}
      params[:q][:user_id_eq] = spree_current_user&.id
      params[:q][:state_not_eq] = 'cart'
      
      load_user_notifications

      # .reverse_chronological
      @orders = Spree::Order.includes(:seller, line_items:[:product] ).ransack(params[:q] ).result.
        order('completed_at desc').page(params[:page]).per(params[:limit] || Spree::Config[:admin_products_per_page] )
      render template:'spree/users/show', layout:'spree/layouts/checkout'
    else
      redirect_to '/'
    end
  end

  def onboarding
    @top_products = cache_of_mostly_viewed_products

    @title = I18n.t('user.update_your_account')
    @spree_user.update_columns(last_passcode_viewed_at: Time.now) if (@spree_user.last_passcode_viewed_at.nil? || params[:force_to_count].to_s == 'true') && params[:skip_count].to_s != 'true'
  end

  ##
  # Different
  def onboarding_change_password
    params.require(:spree_user)
    u_h = params[:spree_user] || {}
    @spree_user.password = u_h[:password]
    logger.debug "| spree_user: #{u_h} -> valid? #{@spree_user.valid?}"
    if u_h[:password].present? && u_h[:password_confirmation].present?
      if @spree_user.reset_password(u_h[:password], u_h[:password_confirmation] )

        logger.debug " .. signing in #{@spree_user.display_name}"
        @spree_user.update_columns(passcode: nil)
        sign_in(:spree_user, @spree_user)

        respond_to do|format|
          format.html { redirect_to contact_info_path }
        end
      end

    else
      @spree_user.errors.add(:password, t('devise.user_passwords.user.cannot_be_blank'))
    end

    if @spree_user.errors.size > 0
      logger.debug "| spree_user.errors #{@spree_user.errors.messages}"
      respond_to do|format|
        format.html { render :onboarding }
      end
    end
  end

  protected

  ##
  # If seller would redirect to payment methods
  def check_for_seller_account
    if spree_current_user&.pending_seller? || spree_current_user&.approved_seller?
      redirect_to admin_store_payment_methods_path
    end
  end

  def load_user
    params.require(:passcode)
    @spree_user = if params[:passcode].present?
      if params[:passcode] =~ /\A\d+\Z/ # only number, would be Spree::User#id
        Spree::User.where(id: params[:passcode].to_i ).first
      else
        Spree::User.where(passcode: params[:passcode] ).first
      end
    else
      nil
    end
    if @spree_user.nil?
      logger.debug " -> not found w/ #{params}"
      redirect_to ioffer_seller_onboarding_path
    elsif params[:action] == 'onboarding_change_password' && request.method == 'GET'
      redirect_to user_onboarding_path(passcode: params[:passcode])
    end
  end

end

Spree::UsersController.prepend(Spree::UsersControllerDecorator) if Spree::UsersController.included_modules.exclude?(Spree::UsersControllerDecorator)
