module Ioffer::PaymentsHelper

  ##
  # Creates a box w/ checkbox
  # @which_payment [either PaymentMethod or String w/ payment_methods.name]
  def payment_card(which_payment, base_css_class = '')
    pm = which_payment.is_a?(Ioffer::PaymentMethod) ? which_payment : cache_of_ioffer_payments[which_payment.downcase]
    return content_tag(:i) if pm.nil?
    icon_path = asset_path("payment_methods/#{which_payment.downcase}.png")

    current_user ||= spree_current_user&.ensure_ioffer_user!
    has_payment_method = current_user ?
      current_user.user_payment_methods.collect(&:payment_method_id).include?(pm.id) : nil
    content_tag(:div, class:"#{base_css_class}#{' payment-selected' if has_payment_method}") do
      content_tag(:div, class:'payment-content', style: "background-image:url('#{icon_path}')", title: pm.display_name, 'data-toggle'=>'tooltip' ) do
        check_box_tag('payment_method_ids[]', pm.id, has_payment_method )
      end
    end
  end

  ##
  # 
  def payment_method_card(payment_method, has_payment_method = nil, base_css_class = '')
    icon_path = asset_path("payment_methods/#{payment_method.name.downcase}.png")

    has_payment_method ||= spree_current_user ?
      spree_current_user.store_payment_methods.collect(&:payment_method_id).include?(payment_method.id) : nil
    content_tag(:div, class:"#{base_css_class}#{' payment-selected' if has_payment_method}") do
      content_tag(:div, class:'payment-content', style: "background-image:url('#{icon_path}')", title: payment_method.description, 'data-toggle'=>'tooltip' ) do
        check_box_tag('payment_method_ids[]', payment_method.id, has_payment_method )
      end
    end
  end

  ##
  # @user [Ioffer::User or Spree::CurerntUser]
  # @return [Hash name => Ioffer::PaymentMethod]
  def user_ioffer_payment_methods(user)
    return {} if user.nil?
    ioffer_user = user.is_a?(Ioffer::User) ? user : user.ensure_ioffer_user!
    unless @user_ioffer_payment_methods
      @user_ioffer_payment_methods = {}
      ioffer_user.payment_methods.each do|ioffer_pm|
        @user_ioffer_payment_methods[ioffer_pm.name] = ioffer_pm
      end
    end
    @user_ioffer_payment_methods
  end

  ##
  # @return [Hash name => Ioffer::PaymentMethod]
  def cache_of_ioffer_payments
    unless @cache_of_ioffer_payments
      @cache_of_ioffer_payments = Rails.cache.fetch 'payments.ioffer_payment_methods' do
        h = {}
        Ioffer::PaymentMethod.all.each do|p|
          h[p.name.downcase] = p
        end
        h
      end
    end
    @cache_of_ioffer_payments
  end
end
