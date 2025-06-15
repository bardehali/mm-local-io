module Spree::Admin::ProductsControllerDecorator

  def self.prepended(base)
    base.include ::Spree::Admin::Shared::AdoptionHelper
    base.include ::Spree::Admin::Shared::VariantEditingHelper
    base.include User::MessagesHelper

    base.helper ::Spree::Admin::MoreProductsHelper
    base.helper ::Spree::Admin::RecordReviewsHelper

    base.helper_method :product_options_map

    base.before_action :set_current_user_id, :set_to_save_currency_prices, :set_option_values, only: [:create, :update, :clone, :list_variants]
    base.before_action :check_which_seller, only: [:edit]

    #base.before_action :load_user_messages, only: [:index]
    base.before_action :load_products, only: [:batch_update]

    base.before_action :authenticate_spree_user!
    base.before_action :check_listing_policy, only: [:new]
    base.before_action :load_latest_wanted_products, only: [:index]


  end

  def index
    unless spree_current_user&.admin?
      load_most_wanted_products
    end
    super
  end

  def update
    if @product.user_variant_option_value_ids
      @product.save_option_values!
    end
    super
  end

  def adopted
    respond_to do|format|
      format.html { render 'spree/admin/products/index' }
    end
  end

  def adoption
    @title = I18n.t('spree.admin.tools.product_adoption')
    logger.debug "| collection: #{@collection.to_sql }"
  end

  def top_selling
    @title = 'Top Selling Items'
    @search = Spree::Product.ransack(line_items_order_state_eq:'complete', s:'transaction_count desc')
    @products = @search.result(distinct: true).
      includes(associated_completed_orders:[:user, seller:[:role_users] ] ).
      page(params[:page]).per(params[:per_page] || Spree::Config[:admin_orders_per_page])

  end

  def show_debug
    authorize_real_admin
    load_resource
  end

  def toggle_selling_taxon
    if params[:taxon_id]
      @user_selling_taxon = Spree::UserSellingTaxon.find_or_initialize_by(user_id: spree_current_user.id, taxon_id: params[:taxon_id])
      if @user_selling_taxon.id
        @user_selling_taxon.destroy
      else
        @user_selling_taxon_new = true
        @user_selling_taxon.save
      end
    end

    respond_to do|format|
      format.js { render 'adoption.js.erb' }
    end
  end

  ##
  # w/ params :product_ids and list of attributes like :iqs or :curation_score
  def batch_update
    params.permit!
    attr_to_update = params.slice(:iqs, :curation_score)
    attr_to_update.delete_if{|k,v| v.nil? || v.blank? }
    logger.info "To update w/ #{attr_to_update}: "
    logger.debug @products.to_sql

    if attr_to_update.to_hash.size > 0
      @products.update( attr_to_update.to_hash.merge(last_review_at: Time.now) )
      # @products.each{|p| p.es.index_document } #
    end

    respond_to do|format|
      format.js { render js:'' }
    end
  end

  def erase
    logger.debug "| Erasing product #{@product.id}"
    @product.really_destroy!
    respond_to do|format|
      format.js
      format.html { redirect_to params[:return_url] || request.referer || admin_products_path }
    end
  end

  def list_same_item
    @title = I18n.t('store.adopt.list_same_item')
    load_resource
    @variant_price = @product.variant_adoption_for(spree_current_user)&.price
    @recent_transactions =  fetch_recent_transactions(@product)
    @order = Spree::Order.find_by(guest_token: params[:rid])
  end

  def valid_order_token?
    @order.present? && params[:rid].present? && params[:rid] == @order.guest_token
  end

  def fetch_recent_transactions(product)
    # Replace with actual logic to retrieve recent transactions for the product
    Spree::LineItem.joins(:order).where(product_id: product.id).order('spree_orders.completed_at DESC').limit(36)
  end

  ##
  # Non-product owner creating multiple variants with given
  def list_variants
    params.permit!
    load_resource
    @product.validate_for_list_variants unless request.method == 'GET'

    if @product.errors.count > 0
      logger.debug "| list_variants stuck w/ errors: #{@product.errors.full_messages}"

      load_option_types_and_values

      render :list_same_item
    else
      # if @product.user_variant_option_value_ids
      @product.save_option_values!(params, spree_current_user&.id)
      @product.schedule_to_update_variants!

      spree_current_user&.schedule_to_calculate_stats!
      flash[:notice] = I18n.t('store.item_successfully_posted', product_id: @product.id)
      if params[:return_url].present?
        redirect_to params[:return_url]
      else
        redirect_to admin_find_and_list_items_path(product_id: @product.id)
      end
    end
  end

  ##
  # For current user or given user
  def product_options_map(user_id = nil)
    @product_options_map_to_user_id ||= {}
    user_id ||= spree_current_user&.admin? ? nil : spree_current_user.try(:id)
    _product_options_map = @product_options_map_to_user_id[user_id]
    unless _product_options_map
      _product_options_map ||= @product.options_map(user_id, exclude_zero_value: false)
      @product_options_map_to_user_id[user_id] = _product_options_map
      logger.debug "| options_map of #{user_id} (vs #{@product.user_id}): #{_product_options_map}" if Rails.env.development?
    end
    _product_options_map
  end

  protected

  def exception_path?
    true
  end

  def location_after_save
    @product.id && (params[:action] == 'create' || params[:tab]=='details') ? spree.admin_product_images_path(@product) : super
  end

  def collection_actions
    [:index, :adopted, :products_adopted, :adoption, :toggle_selling_taxon]
  end

  ##
  # If seller to adopt, change :edit to :list_same_item
  def check_which_seller
    unless spree_current_user&.id == @product.user_id || spree_current_user&.admin?
      redirect_to admin_list_same_item_path(@product)
    end
  end

  def set_current_user_id
    if @product
      @product.user_id ||= spree_current_user.try(:id)
      @product.last_review_at = Time.now if spree_current_user.try(:admin?)
    end
    @new.user_id = spree_current_user.try(:id) if @new
  end

  def set_to_save_currency_prices
    @product.price_attributes ||= permitted_resource_params[:price_attributes]
    @product.apply_price_attributes( !@product.new_record? )
  end


  ##
  # Copied over code and then added w/ extra current user only condition.
  def collection
    return @collection if @collection
    if %w(adoption toggle_selling_taxon).include?( params[:action] )
      load_products_for_adoption
    elsif %w(adopted products_adopted other_listings).include?(params[:action])
      @page_title = spree_current_user&.admin? ?
        Spree.t('products') + ' ' + Spree.t('admin.products.adopted') : t('product.other_listings')
      load_products_adopted
    else
      @page_title ||= spree_current_user&.admin? ? Spree.t('products') : t('product.my_products')

      params[:q] ||= {}
      params[:q][:s] ||= spree_current_user&.admin? ? 'view_count desc' : 'id desc'
      joining_variants = false
      if spree_current_user && !spree_current_user.admin?
        # joining_variants = true
        params[:q][:user_id_eq] = spree_current_user.id
      end
      @user = Spree::User.find_by_id(params.fetch(:q,{})[:user_id_eq]) if params.fetch(:q,{})[:user_id_eq]
      @page_title << " by #{@user.login}" if @user && @page_title.present? && spree_current_user&.admin?

      # @search needs to be defined as this is passed to search_form_for
      logger.debug "| params now #{params}"
      @search = super.ransack(params[:q])
      @collection = @search.result(distinct: joining_variants).
          # order(id: :asc).
          includes(product_includes + [:variant_images]).
          page(params[:page])
          #.
          #per(Spree::Config[:admin_products_per_page] )
      @collection = @collection.with_acceptable_status if show_only_acceptable_products?

      logger.debug "| products#index.collection = #{@collection.to_sql}"

      @collection
    end
  end



  ##
  # Originally called by Spree::Admin::ImagesController#load_data
  def load_variants
    @product ||= Spree::Product.friendly.find(params[:product_id])
    @variants = @product.variants.includes(:preferred_variant_adoption => [:prices], :option_value_variants => [:option_value => :option_type] ).collect do |variant|
      [variant.sku_and_options_text, variant.id]
    end
    @variants.insert(0, [t('spree.all'), @product.master.id])
  end

  def load_products
    @products = Spree::Product.includes(:record_review)
    if params[:product_ids].to_a.size > 0 && params[:commit].match(/update\s+all/i).nil?
      @products = @products.where(id: params[:product_ids] )
    else
      @products = @products.not_reviewed
    end
  end

  def load_user_messages
    logger.debug "| load_user_messages or not? #{spree_current_user&.seller?}"
    if spree_current_user&.seller?
      load_user_notifications
    end
  end

  def check_listing_policy
    unless session['agreed_to_listing_policy'].present? || spree_current_user.agreed_to_listing_policy?
      session['spree_user_return_to'] = request.fullpath
      logger.debug " -> #{spree_current_user} needs to item_listing_policy"
      redirect_to admin_item_listing_policy_path(t: Time.now.to_i)
    end
  end
end


::Spree::Admin::ProductsController.prepend(::Spree::Admin::ProductsControllerDecorator) if ::Spree::Admin::ProductsController.included_modules.exclude?(::Spree::Admin::ProductsControllerDecorator)
::Spree::Admin::ProductsController.helper_method :valid_order_token?
