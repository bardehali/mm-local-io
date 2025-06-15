module Spree::Admin::StoresControllerDecorator

  def self.prepended(base)
    base.include ::Spree::Admin::Shared::AdoptionHelper
    base.helper_method :get_latest_sale_image_for_taxon

    base.skip_before_action :authorize_admin, only: [:fill_your_shop]
    base.before_action :authorize_to_adopt_products, only: [:fill_your_shop, :find_and_list_items]
    base.before_action :load_products_for_adoption, only: [:fill_your_shop]
    base.before_action :load_most_wanted_products, only: [:find_and_list_items]

  end

  def default_title
    'iOffer'
  end

  def fill_your_shop
    @title = I18n.t('store.fill_your_shop')
  end

  def find_and_list_items
    @title = I18n.t('store.adopt.find_and_supply_the_best')
    if params[:product_id] && (@created_product = Spree::Product.find_by(id: params[:product_id]))
      flash[:notice] = I18n.t('store.item_successfully_posted_by_name', name: @created_product.name.truncate(80) )
    end
    render(layout: 'spree/layouts/spree_application')
  end

  def listing_policy
    @title = I18n.t('listing_policy.title')
    render(layout: 'spree/layouts/spree_application')
  end

  def update_listing_policy
    session['agreed_to_listing_policy'] = Time.now.to_s(:db)
    User::Stat.fetch_or_set(spree_current_user.id, Spree::User::AGREED_TO_LISTING_POLICY) do
      Time.now.to_s(:db)
    end
    if (return_path = session['spree_user_return_to'] ).present?
      session['spree_user_return_to'] = nil
      redirect_to return_path
    else
      redirect_to new_admin_product_path
    end
  end

  def update_options
    if params[:user_stats]
      params[:user_stats].each_pair do|name, value|
        stat = ::User::Stat.find_or_initialize_by(user_id: spree_current_user.id,
          name: name.strip)
        stat.value = value&.strip
        stat.save
      end
    end
    critical_response
  end

  def critical_response
    # future may have different conditions to agreements or forms
    @critical_response = true
    if spree_current_user&.required_critical_response?
      show_agree_to_provide_tracking_info
    else
      redirect_to '/admin/wanted_products'
    end
  end

  def index
    admin_user_ids = Spree::RoleUser.where(role_id: Spree::Role.find_by(name:'admin').try(:id) ).collect(&:user_id)
    @stores = Spree::Store.includes(:user, :retail_site, :payment_methods).where("user_id NOT IN (?)", admin_user_ids).page(params[:page]).limit(50)
  end

  protected

  def show_agree_to_provide_tracking_info
    render_opts = { layout:'spree/layouts/only_main_content' }
    @agree_to_provide_tracking_info = ::User::Stat.find_or_initialize_by(user_id: spree_current_user&.id, name:'agree_to_provide_tracking_info')
    if @agree_to_provide_tracking_info&.value.blank? || @agree_to_provide_tracking_info.value != 'true'
      @page_title = I18n.t('seller.to_seller_you_must_agree_to')
      @options = [@agree_to_provide_tracking_info]
      render render_opts.merge(template:'spree/admin/stores/agree_to_provide_tracking_info')
    else
      # iterate over cases
      @order = nil
      if (paypal_store_pm = spree_current_user.store&.paypal_store_payment_method)
        @order = paypal_store_pm&.orders_with_paid_need_tracking_of_same_payment_method_account.order('completed_at asc').first
      end
      @orders = [@order]
      if @order
        @page_title = "Order #{@order.number}: #{t('seller.user_stats.agree_to_provide_tracking_info.title') }"
        render render_opts.merge(template:'spree/admin/orders/show')
      else
        spree_current_user.required_critical_response&.destroy
        redirect_to '/admin'
      end
    end
  end

  def collection_actions
    [:index, :adoption, :fill_your_shop]
  end

  def authorize_to_adopt_products
    unless can?(:adopt, Spree::Product) || spree_current_user.try(:admin?)
      redirect_to '/admin'
    end
  end
end

Spree::Admin::StoresController.prepend(Spree::Admin::StoresControllerDecorator) if Spree::Admin::StoresController.included_modules.exclude?(Spree::Admin::StoresController)
