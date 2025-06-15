class Spree::Admin::StorePaymentMethodsController < Spree::Admin::BaseController

  inherit_resources

  include ControllerHelpers::SellerManager

  helper ::Retail::StoreToSpreeUserHelper

  skip_before_action :authorize_admin
  before_action :store_payment_method_params, only: [:new, :create, :update]

  def index
    load_store_data
  end


  def accounts
    load_store_data
  end

  def toggle
    # params.require(:payment_method_id)
    if params[:payment_method_id]
      @store_payment_method = Spree::StorePaymentMethod.find_or_initialize_by(store_id: spree_current_user.fetch_store.id, payment_method_id: params[:payment_method_id] )
      if @store_payment_method.id
        @store_payment_method.destroy
      else
        @store_payment_method_new = true
        @store_payment_method.save
      end
    end
    respond_to do|format|
      format.html { redirect_to admin_store_payment_methods_path }
      format.js
    end
  end

  def create
    @store_payment_method = ::Spree::StorePaymentMethod.new( store_payment_method_params )
    @store_payment_method.store_id = spree_current_user.fetch_store.id
    create!(notice: '') { store_payment_methods_path(added_payment_method_id: @store_payment_method.payment_method_id) }
  end

  def update
    super do|format|
      format.js
    end
  end

  def save_payment_methods_and_retail_stores
    params.permit!
    logger.debug "of user(#{spree_current_user.id}), store(#{spree_current_user.store_id})--------------------------"
    if params[:user]
      spree_current_user.update(params[:user] )
    end
    
    @store_payment_methods = update_store_payment_methods(spree_current_user.fetch_store, params)
    has_error = @store_payment_methods.any?(&:invalid?)
    logger.debug "| StorePaymentMethods has_error? #{has_error} -----------"

    # update_user_retail_sites(spree_current_user, params)

    logger.debug "params[:other_site_accounts] #{params[:other_site_accounts].class}: #{params[:other_site_accounts]}"
    if params[:other_site_accounts].respond_to?(:each_pair)
      params[:other_site_accounts].each_pair do|site_name, account_id|
        other_site_account = spree_current_user.other_site_accounts.find_or_initialize_by(site_name: site_name)
        if account_id.present?
          other_site_account.account_id = account_id
          other_site_account.save
        else
          other_site_account.destroy if other_site_account.id
        end
      end
    end

    respond_to do|format|
      format.html do 
        if has_error
          @payment_methods ||= @store_payment_methods.collect(&:payment_method)
          if (current_path = params[:current_path] ).present?
            render_args = { template: current_path }
            render_args[:layout] = 'layouts/ioffer_application' if current_path.starts_with?('home/')
            render render_args
          else
            render 'spree/store_payment_methods/accounts'
          end
        else
          redirect_to after_contact_info_path
        end
      end
      format.js { render js: '' }
    end
  end

  protected

  def collection_actions
    [:index, :toggle]
  end

  def after_contact_info_path
    if flash[:warning].present?
      params[:return_url] || request.referer + "?t=#{Time.now.to_i}" || payment_method_accounts_path
    elsif params[:next_path].present?
      params[:next_path]
    elsif session['passed_geofence'] 
      admin_wanted_products(t: Time.now.to_i)
    else
      '/admin'
    end
  end

  private

  def store_payment_method_params
    params.require(:store_payment_method).permit(:payment_method_id, :account_parameters, :account_label, :account_id, :instruction)
  end

end
