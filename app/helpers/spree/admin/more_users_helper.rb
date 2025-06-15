module Spree::Admin::MoreUsersHelper
  def ransack_sellers_sort_options
    options_for_select [
      ['GMS Desc', 'ioffer_user_gms desc'],
      ['Last Email Desc', 'last_email_at desc'],
      ['Last Login Desc', 'last_sign_in_at desc'],
    ], params[:q].try(:[], :s)
  end

  ##
  # @ioffer_user [Ioffer::User]
  def source_of_ioffer_user(ioffer_user)
    if ioffer_user.created_at < Ioffer::User::END_OF_IMPORTED_USERS
      'legacy'
    else
      'organic'
    end
  end

  ##
  # Possible wanted blank text when list is empty.
  # @list [Enumerable of String]
  def list_of_values(list, none_text = 'none')
    if list.blank?
      content_tag(:span, class:'none-text') { none_text }
    else
      list.join(', ')
    end
  end

  ##
  # This would use filter if show_only_acceptable_products?
  def products_count_for(user, list_of_users = nil)
    unless @cache_of_products_count
      list_of_users ||= @users || [user]
      query = Spree::Product.distinct('id').where(user_id: list_of_users.collect(&:id) )
      query = query.with_acceptable_status if show_only_acceptable_products?
      @cache_of_products_count = query.group('user_id').count
    end
    @cache_of_products_count[user.id] || 0
  end

  def products_adopted_count_for(user, list_of_users = nil)
    unless @cache_of_products_adopted_count
      list_of_users ||= @users || [user]
      @cache_of_products_adopted_count = Spree::Product.adopted_by(list_of_users.collect(&:id)).group("#{Spree::VariantAdoption.table_name}.user_id").distinct('product_id').count
    end
    @cache_of_products_adopted_count[user.id] || 0
  end

  def request_logs_list(request_logs, starting_index = 0, list_html_attributes = {})
    content_tag :ul, { class:'list-unstyled' }.merge(list_html_attributes) do
      request_logs.each_with_index do|request_log, idx|
        next if idx < starting_index
        concat content_tag(:li, class:"text-monospace text-right", title:" at #{relative_short_time(request_log.created_at)}", data:{ toggle: "tooltip"} ) {
          inner_s = request_log.ip.to_s
          if request_log.country.present?
            inner_s << "<span class='text-info'> in #{request_log.location_combined}</span>"
          end
          inner_s.html_safe
        }
      end # each
    end # ul
  end

  ##
  # Seller Status

    ##
  # @return [String] HTML of tags.  So use .html_safe in view level
  def admin_user_link_with_status(user)
    tags = [ link_to(edit_admin_user_path(id: user.id) ) { user.email }.to_s ]
    tags << seller_type_icon(user).to_s
    tags << content_tag(:span, title:'Days seller since active') { "(#{user.days_not_active})" }.to_s
    tags.join("\n")
  end

  ##
  # @return HTML tag
  def seller_type_icon(user)
    if user.phantom_seller?
      content_tag(:span, class:'pending-seller-p seller-role-outline') { "👻" }
    elsif user.pending_seller?
      content_tag(:span, class:'pending-seller-p') { 'P' }
    elsif user.fake_user?
      content_tag(:span, class:'pending-seller-p') { 'C' }
    elsif user.test_user?
      content_tag(:span, class:'pending-seller-p') { 'T' }
    else
      ''
    end
  end

  def seller_status_icons(user = nil)
    user ||= spree_current_user
    return '' if user.nil?
    tags = []
    if (days_out = user.days_not_active) > 365 || user.last_active_at.nil?
      # tags << content_tag(:span, class:'icon icon-ban-circle text-danger text-larger', title:'Not logged in') { ' ' }
      tags << content_tag(:image, class:'circle-button', 'data-toggle'=>'tooltip', src: asset_path('ban-circle.svg'), title: user.current_sign_in_at ? "Not active in #{days_out} days" : 'Never logged in') {}
    end
    if account_empty_or_low?(user)
      tags << content_tag(:image, class:'circle-button', 'data-toggle'=>'tooltip', src: asset_path('circular-dollar.svg'), title:'Account is empty/low') {}
    end
    if (buyers_cannot_pay = count_of_buyer_cannot_pay_cases(user)).to_i > 0
      tags << content_tag(:image, class:'circle-button', 'data-toggle'=>'tooltip', src: asset_path('hexagonal-dollar.svg'), title:"#{buyers_cannot_pay} Buyers have complained they cannot pay") {}
    end
    if new_seller_no_buyer_feedback?(user)
      tags << content_tag(:image, class:'circle-button', 'data-toggle'=>'tooltip', src: asset_path('walker-yellow.svg'), title:"New seller no buyer feedback") {}
    end
    if paypal_in_good_standing?(user)
      tags << content_tag(:image, class:'circle-button', 'data-toggle'=>'tooltip', src: asset_path('payment_methods/mini_avatar/paypal.svg'), title:'PayPal in Good Standing') {}
    end
    tags << seller_type_icon(user) if user
    tags
  end

  ROLE_PRECEDENCE_ORDER = %w(quarantined phantom curated fake pending handpicked hp approved)

  # Show the earliest included role compared to ROLE_PRECEDENCE_ORDER
  # @options [Hash]
  #   :link_text [String] instead of user.login, show this in link instead
  # @return [a tag]
  def user_id_link_with_roles_stylized(user, options = {})
    all_roles = user.spree_roles.collect(&:short_name)
    roles_in_order = ROLE_PRECEDENCE_ORDER & all_roles
    days_inactive = user.last_active_at ? user.days_not_active : nil
    content_tag(:a, href: admin_user_path(user), class: "user-role user-role-#{roles_in_order.first}", title: all_roles.join(', '), target:'_blank') do
      if days_inactive
        concat content_tag(:span, class:"text-smaller mr-1 #{days_inactive < 7 ? 'text-secondary' : 'text-dark'}", title:"Days since active: #{user.last_active_at.to_s(:long)}" ) { days_inactive.to_s }
      end
      concat " #{options[:link_text] || user.login}"
    end
  end

  def country_icon_or_name(user)
    if user&.country_code.present?
      content_tag(:span, class:"country-icon#{' grayscale' if user.country&.downcase == 'china'}", title: user.country) do
        inline_svg_tag("flags/4x3/#{user.country_code.downcase}.svg", size: '2.6em*1.3em')
      end
    else
      content_tag(:span, 'country-name' => user&.country ) { }
    end
  end

  def paypal_in_good_standing?(user = nil)
    user ||= spree_current_user
    return false if user.nil?

    user.fetch_store.has_paypal?
  end

  def account_empty_or_low?(user = nil)
    user ||= spree_current_user
    return true if user.nil?
    activity_count = (user.count_of_products_created || Spree::Product.where(user_id: user.id).count ) + 
      (user.count_of_transactions || Spree::Order.complete.not_by_unreal_users.where(seller_user_id: user.id).count )
    activity_count == 0
  end

  def count_of_buyer_cannot_pay_cases(user = nil)
    user ||= spree_current_user
    return user.non_paying_buyer_count.to_i
  end

  def new_seller_no_buyer_feedback?(user = nil)
    user ||= spree_current_user
    user.ioffer_user ? user.ioffer_user.rating.to_f == 0.0 : true
  end

  def view_mode
    params[:view] == 'cards' || (%w(sellers all_sellers).include?(params[:action] ) && params[:view] != 'table') ? 'cards' : 'table'
  end

  def match_to_others_icons(user = nil)
    user ||= spree_current_user
    tags = []
    unless @ip_to_match_counts || @users.nil?
      user_ips = @users.to_a.collect(&:current_sign_in_ip)
      @ip_to_match_counts = Spree::User.select('current_sign_in_ip').where(current_sign_in_ip: user_ips).group(:current_sign_in_ip).count
    end
    ip_match_count =
      if user.current_sign_in_ip.blank?
        0
      elsif @ip_to_match_counts
        @ip_to_match_counts[user.current_sign_in_ip].to_i
      else
        Spree::User.where(current_sign_in_ip: user.current_sign_in_ip).count
      end
    if ip_match_count > 1
      tags << link_to( admin_users_path(q:{ current_sign_in_ip_eq: user.current_sign_in_ip }, view: view_mode),
        class:'text-positive', 'data-toggle'=>'tooltip',
        title:"IP: #{user.current_sign_in_ip} - #{ip_match_count} matches" ) do
          content_tag(:i, 'data-feather'=>'globe') { }
        end
    end
    tags
  end

  def curated_products(user = nil, limit = 5)
    user ||= spree_current_user
    Spree::Product.includes(master:[:images]  ).where(user_id: user.id).order('view_count DESC, id DESC').limit(limit).to_a
  end
end
