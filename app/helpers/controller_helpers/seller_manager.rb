module ControllerHelpers::SellerManager
  extend ActiveSupport::Concern
  
  def self.included(base)
    # base.before_action :load_order, except: :update_positions
  end

  ##
  # Replaces real admin level authorization w/ check against order's seller.
  # To be used by manage actions of existing record.
  def authorize_admin
    record = load_order
    authorize! action, record
  end

  def load_order
    @order ||= ::Spree::Order.includes(:adjustments).find_by!(number: params[:order_id] || params[:id])
  end

  ##
  # Loads instance variables @payment_methods, @other_site_account
  def load_store_data
    store_pm_map = store_payment_methods.group_by(&:payment_method_id)
    store_site_map = ::Retail::StoreToSpreeUser.joins(:retail_store).where(spree_user_id: spree_current_user.id ).all.group_by(&:retail_site_id)
    logger.debug "| store_site_map: #{store_site_map}"
    @retail_sites = ::Retail::Site.where(user_selectable: true).order('position asc').all.collect do|retail_site|
      retail_site.retail_store = store_site_map[retail_site.id].try(:first).try(:retail_store)
      retail_site
    end

    pm_query = Spree::PaymentMethod.selectable_for_store(spree_current_user.fetch_store.id)
    pm_query = pm_query.where(id: params[:payment_method_ids]) if params[:payemt_method_ids].present?
    @payment_methods = pm_query.distinct.order('position asc').all.collect do|payment_method|
      payment_method.store_payment_method = store_pm_map[payment_method.id].try(:first)
      payment_method
    end

    @other_site_account = Retail::OtherSiteAccount.where(user_id: spree_current_user.id).first
  end

  REQUIRES_ACCOUNT_ID = true
  REQUIRES_INSTRUCTION = false

  ##
  # Create, update or delete Spree::StorePaymentMethod of this store.
  # To allow selection of certain payment methods, with params[:require] == 'all'
  # would be able to create Spree::StorePaymentMethod w/o account or instruction.
  # If requires all, next condition depends on REQUIRES_ACCOUNT_ID and REQUIRES_INSTRUCTION, 
  # if neither account_id and instruction provided,
  # would delete entry, and create flash[:warning] message; 
  # else params[:payment_method_ids] would create an entry.
  # @return [Array of Spree::StorePaymentMethod] This would even include ones w/ ActiveRecord::Errors
  def update_store_payment_methods(store, params)
    store = spree_current_user.fetch_store
    payment_method_ids_to_delete = []
    payment_method_ids_added = []

    require_all = params[:require].to_s == 'all' # validation
    store_payment_methods = []
    
    ( params[:payment_method_account_ids] || {} ).each_pair do|_payment_method_id, account_id|
      payment_method_id = _payment_method_id.to_i
      instruction = params["store_payment_method_instruction_#{payment_method_id}"]
      enough_account_id = account_id.present? || !REQUIRES_ACCOUNT_ID
      enough_instruction = instruction.present? || !REQUIRES_INSTRUCTION
      store_pm = Spree::StorePaymentMethod.find_or_initialize_by(store_id: store.id, payment_method_id: payment_method_id)
      if (enough_account_id) && (enough_instruction)
        store_pm.account_id = account_id
        store_pm.instruction = instruction ? instruction.compact : nil
        store_pm.save
        payment_method_ids_added << payment_method_id
        logger.debug "| payment_method #{payment_method_id} w/ #{account_id} => valid? #{store_pm.valid?}, errors: #{store_pm.errors.messages}"
      else
        if require_all # validating but don't delete
          msgs = []
          msgs << I18n.t('user.payment_methods.please_enter_your_email', service:'') unless enough_account_id
          msgs << I18n.t('user.payment_methods.please_enter_your_instruction', service:'') unless enough_instruction
          flash[:warning] = msgs.join('.  ') if msgs.present?
          payment_method_ids_added << payment_method_id if store_pm&.id
        else
          payment_method_ids_to_delete << payment_method_id.to_i
        end
      end
      store_payment_methods << store_pm
    end

    if payment_method_ids_to_delete.size > 0
      Spree::StorePaymentMethod.where(store_id: store.id, payment_method_id: payment_method_ids_to_delete).delete_all
    end

    if params[:payment_method_ids]
      params[:payment_method_ids].each do|payment_method_id|
        next if payment_method_ids_added.include?(payment_method_id)
        store_pm = Spree::StorePaymentMethod.find_or_create_by(store_id: store.id, payment_method_id: payment_method_id)
        store_pm.save
        payment_method_ids_added << payment_method_id
      end
      Spree::StorePaymentMethod.where(store_id: store.id).where('payment_method_id NOT IN (?)', payment_method_ids_added ).delete_all
      store.user&.schedule_to_calculate_stats!
    end
    store_payment_methods
  end

  def update_user_retail_sites(user, params)
    retail_site_ids_to_delete = []
    ( params[:retail_site_account_ids] || {} ).each_pair do|retail_site_id, store_id|
      if store_id.present?
        rstore = Retail::Store.find_or_create_by(retail_site_id: retail_site_id, retail_site_store_id: store_id)
        logger.debug "| rstore: #{rstore.as_json}"
        store_to = Retail::StoreToSpreeUser.find_or_initialize_by(retail_store_id: rstore.id, spree_user_id: user.id)
        store_to.retail_site_id = retail_site_id
        store_to.save
        logger.debug "| store_to: #{store_to.as_json}"
      else
        retail_site_ids_to_delete << retail_site_id
      end
    end

    if retail_site_ids_to_delete.size > 0
      Retail::StoreToSpreeUser.where(retail_site_id: retail_site_ids_to_delete, spree_user_id: spree_current_user.id).delete_all
    end
  end

  protected

  ##
  # Those of current user's store
  def store_payment_methods
    return @store_payment_methods if @store_payment_methods
    store = spree_current_user.fetch_store
    @store_payment_methods = Spree::StorePaymentMethod.where(store_id: store.id)
  end
end