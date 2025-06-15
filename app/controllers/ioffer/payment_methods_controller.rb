class Ioffer::PaymentMethodsController < Ioffer::IofferBaseController

  before_action :check_signed_in_user

  def index
    logger.debug "| Signed in user: #{session[:signed_in_user]} > current user #{current_user} vs spree_current_user #{spree_current_user}"

    @page_title = "#{t('site_name')} - Payments"
    render template: 'home/payments'
  end

  def select_payment_methods
    params.permit(:payment_method_ids, :other_payment_method)
    pm_ids = Ioffer::PaymentMethod.where(id: params[:payment_method_ids] || [] ).collect(&:id)
    current_user ||= spree_current_user.try(:ioffer_user)
    if current_user
      if pm_ids.size > 0
        Ioffer::UserPaymentMethod.where(user_id: current_user.id).delete_all
        pm_ids.each{|pm_id| Ioffer::UserPaymentMethod.create(user_id: current_user.id, payment_method_id: pm_id) }
      end
      if params[:other_payment_method].present?
        name = params[:other_payment_method].to_underscore_id
        pm = Ioffer::PaymentMethod.find_or_create_by(name: name) do|_pm|
          _pm.display_name = params[:other_payment_method]
          _pm.is_user_created = true
        end
        if pm && pm.id
          logger.info "| payment method: #{pm.attributes}"
          pm.update(display_name: params[:other_payment_method] ) if pm.display_name.blank?
          current_user.user_payment_methods.find_or_create_by(payment_method_id: pm.id)
        end
      end

      current_user.convert_payment_methods!

    elsif spree_current_user
      store = spree_current_user.fetch_store
      Ioffer::PaymentMethod.where(id: params[:payment_method_ids] || [] ).all.each do|ioffer_pm|
        pm = Spree::PaymentMethod.find_or_initialize_by(name: ioffer_pm.name)
        pm.description = ioffer_pm.display_name
        pm.save
        Spree::StorePaymentMethod.find_or_create_by(store_id: store.id, payment_method_id: pm.id) if pm&.id
      end
    end

    respond_to do|format|
      format.js { render(js:'') }
      format.html { redirect_to '/categories_brands' }
    end
  end


end
