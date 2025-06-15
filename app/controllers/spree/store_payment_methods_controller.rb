class Spree::StorePaymentMethodsController < Spree::Admin::StoresController

  inherit_resources

  helper Spree::MoreUsersHelper

  before_action :store_payment_method_params, only: [:new, :create, :update]

  def create
    @store_payment_method = ::Spree::StorePaymentMethod.new( store_payment_method_params )
    @store_payment_method.store_id = spree_current_user.fetch_store.id
    create!(notice: '') { store_payment_methods_path(added_payment_method_id: @store_payment_method.payment_method_id) }
  end

  def payment_methods_provided
    @page_title = @title = I18n.t('user.payment_methods.select_all_you_provide')
    spree_current_user.store_payment_methods
    @payment_methods = Spree::PaymentMethod.selectable_for_store(spree_current_user&.fetch_store&.id)
    render layout: 'layouts/ioffer_application'
  end

  def accounts
    @page_title = @title = I18n.t('user.payment_methods.payment_options')
    @store_payment_methods = Spree::StorePaymentMethod.joins(:payment_method).includes(:payment_method).where(store_id: spree_current_user&.fetch_store&.id).order("position asc")
    @payment_methods = Spree::PaymentMethod.selectable_for_store(spree_current_user&.fetch_store&.id)

    render layout: 'layouts/ioffer_application'
  end

  private

  def store_payment_method_params
    params.require(:store_payment_method).permit(:payment_method_id, :account_parameters, :account_label)
  end

end
