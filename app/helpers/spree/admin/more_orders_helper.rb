module Spree
  module Admin
    module MoreOrdersHelper
      def payment_method_mini_icon(payment_method)
        pm_name = payment_method&.name&.downcase&.underscore
        if %w(alipay apple_pay bitcoin ipaylinks paypal paysend ping scoinpay transferwise wechat western_union worldpay).include?(pm_name)
          content_tag :image, src: asset_path("payment_methods/mini_icon/#{pm_name}.png"), title: payment_method.description, class:'mini-icon' do
          end
        else
          ''
        end
      end

      def display_pay_with_button(order)
        payment_method = order.payments.first&.payment_method
        if payment_method
          html_tags = []
          if order.paid?
            html_tags << button_tag(class:'pay-button paid-with-button', id:"order_pay_with_button_#{order.id}") do
                content_tag(:i) do
                  "#{payment_method.description} #{Spree.t('payment_states.paid').titleize}"
                end + 
                '  ' + 
                content_tag(:i, class:'icon icon-ok-circle') { '' }.html_safe
              end
          else
            html_tags << link_to(approve_admin_order_path(order), remote: true, method: 'put', class: 'pay-button pay-with-button', id:"order_pay_with_button_#{order.id}", title: I18n.t('payment.approve_payment') ) do
                content_tag(:i) do
                  "#{payment_method.description} #{Spree.t('payment_states.paid').titleize}"
                end +
                " - #{order.display_total.to_html}" + 
                content_tag(:i, class:'icon icon-circle') { '' }.html_safe
              end
          end
          safe_join(html_tags, ''.html_safe)
        else # No payment method
          ''
        end
      end

      ##
      # @time_length [Integer] amount of time, such as '1.day', '1.week'
      def txns_per_time_period(time_length, how_many_time_data = 30, params = {})
        return nil unless spree_current_user&.admin?
        how_many_time_data ||= 30
        
        instance_name = build_instance_variable_name('txns', time_length, how_many_time_data)
        txns_per = instance_variable_get(instance_name)
        return txns_per if txns_per
        txns_per = ActiveSupport::HashWithIndifferentAccess.new
        txns_per_queries = ActiveSupport::HashWithIndifferentAccess.new
        time_label_format = (time_length <= 1.day) ? '%a, %-m/%-d' : '%-m/%-d'
        if Rails.env.development? # fake data
          (how_many_time_data - 1).downto(0) do|i|
            exact_time = Time.now.beginning_of_week(:monday) - (i * time_length)
            cnt = how_many_time_data + rand(10) - 5
            _label = (time_length == 1.day && i == 1) ? 'Y' : exact_time.strftime(time_label_format)
            txns_per[_label] = cnt
            txns_per_queries[_label] = 'SOME Queries'
          end
        else
          (how_many_time_data - 1).downto(0) do|i|
            exact_time = Time.now.beginning_of_week(:monday) - (i * time_length)
            q = Spree::LineItem.joins(:order).where("completed_at is not null").distinct('order_id').
              where('completed_at between ? and ?', exact_time, exact_time + time_length)
            q = q.where(product_id: params[:with_product_id] ) if params[:with_product_id]
            if (seller_user_id = params[:q].try(:[], :seller_user_id_eq) )
              q = q.where("seller_user_id = #{seller_user_id}")
            end
            _label = (time_length == 1.day && i == 1) ? 'Y' : exact_time.strftime(time_label_format)
            txns_per[_label] = q.count('order_id')
            txns_per_queries[_label] = q.to_sql
          end
        end
        instance_variable_set(instance_name, txns_per)
        instance_variable_set(instance_name + '_queries', txns_per_queries)
        txns_per
      end

      ##
      # @specific_product_ids [Array of Integer, Spree::Product.id]
      def txns_daily(params = {})
        txns_per_time_period(1.day, nil, params)
      end

      ##
      # @specific_product_ids [Array of Integer, Spree::Product.id]
      def txns_weekly(params = {})
       txns_per_time_period(1.week, nil, params)
      end

      ##
      # User based
      def complaints_per_time_period(time_length, params = {})
        return nil unless spree_current_user&.admin?
        instance_name = build_instance_variable_name('complaints', time_length)
        complaints_per = instance_variable_get(instance_name)
        return complaints_per if complaints_per
        complaints_per = ActiveSupport::HashWithIndifferentAccess.new
        complaints_per_queries = ActiveSupport::HashWithIndifferentAccess.new
        time_label_format = (time_length <= 1.day) ? '%a, %-m/%-d' : '%-m/%-d'
        if false && Rails.env.development? # fake data
          30.downto(0) do|i|
            exact_time = Time.now.beginning_of_week(:monday) - (i * time_length)
            cnt = 30 + rand(10) - 5
            _label = (time_length == 1.day && i == 1) ? 'Y' : exact_time.strftime(time_label_format)
            complaints_per[_label] = cnt
            complaints_per_queries[_label] = 'SOME Queries'
          end
        else
          30.downto(0) do|i|
            exact_time = Time.now.beginning_of_week(:monday) - (i * time_length)
            q = Spree::Order.complete.with_complaint.
              where("#{::User::Message.table_name}.created_at between ? and ?", exact_time, exact_time + time_length)
            q = q.where(product_id: params[:with_product_id] ) if params[:with_product_id]
            if (seller_user_id = params[:q].try(:[], :seller_user_id_eq) )
              q = q.where("seller_user_id = #{seller_user_id}")
            end
            _label = (time_length == 1.day && i == 1) ? 'Y' : exact_time.strftime(time_label_format)
            complaints_per[_label] = q.count
            complaints_per_queries[_label] = q.to_sql
          end
        end
        instance_variable_set(instance_name, complaints_per)
        instance_variable_set(instance_name + '_queries', complaints_per_queries)
        complaints_per
      end

      def complaints_weekly(params = {})
        complaints_per_time_period(1.week, params)
      end

      private

      def build_instance_variable_name(object_type, time_length, how_many_time_data = 30)
        instance_name = case time_length
        when 1.year
          "@#{object_type}_yearly"
        when 1.month
          "@#{object_type}_monthly"
        when 1.week
          "@#{object_type}_weekly"
        else 1.day
          "@#{object_type}_daily"
        end
        instance_name + "_for_#{how_many_time_data}"
      end

    end # MoreOrdersHelper
  end
end