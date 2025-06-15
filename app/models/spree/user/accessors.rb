###################################
# Attributes for Spree::User

module Spree::User::Accessors
  extend ActiveSupport::Concern

  included do
    delegate :can?, to: :ability

    attr_accessor :variant, :variant_adoption # for comparison among sellers' variants
  end


  UNWANTED_SEND_TO_EMAIL_COUNTRIES = %w(china)

  ##
  # Devise requires confirmation before login if user's confirmable
  def active_for_authentication?
    deleted_at.nil?
  end

  def active?
    days_not_active.days < Spree::User::TIME_MARK_BEING_ACTIVE
  end

  def days_not_active
    return 500 if last_active_at.nil? && current_sign_in_at.nil?
    ((Time.now - [last_active_at, current_sign_in_at].compact.max ) / 1.day).to_i
  end
  alias_method :days_inactive, :days_not_active

  def confirmation_required?
    !fake_user?
  end

  def to_s
    "#{email} (#{id}, #{username})"
  end

  ##
  # Ensures always have some value.  Precedence of attributes to check: display_name, username
  def try_display_name
    [ self.attributes[:display_name], username].find(&:present?)
  end

  ##
  # Somewhere has this as method w/ argument instead of DB table's column.
  def display_name(name = nil)
    try_display_name
  end

  ##
  # Better for admin to see real ID reference.
  def username_or_email
    [username, email].find(&:present?)
  end

  PREFIXED_USERNAME_REGEXP = /\A(aliexpress|ioffer)\d+/ unless defined?(PREFIXED_USERNAME_REGEXP)

  ##
  # Imported stores like Aliexpress might have prefix like 'aliexpress3000' because username
  # attribute's value restriction requires alphabet at start.
  def real_username
    username ? username.gsub(PREFIXED_USERNAME_REGEXP, ' ') : nil
  end

  def censored_display_name
    [ self.attributes[:display_name], username].find(&:present?)
  end

  FIRSTNAME_LASTNAME_REGEXP = /(.+)\s+(\S+)\Z/i unless defined?(:FIRSTNAME_LASTNAME_REGEXP)

  def firstname
    n = try_display_name
    n.index(' ').nil? ? n : n.match(FIRSTNAME_LASTNAME_REGEXP)[1]
  end

  def lastname
    n = try_display_name
    n.index(' ').nil? ? '' : n.match(FIRSTNAME_LASTNAME_REGEXP)[2]
  end

  def acceptable_ip?(ip)
    ip.present? &&  ['127.0.0.1', '::1'].exclude?(ip)
  end

  def acceptable_send_to_email?
    unwanted = false
    Spree::User::COUNTRY_BASED_EMAIL_REGEXP_MAP.each_pair do|email_regex, country|
      next if unwanted
      if email_regex.match(email)
        unwanted = UNWANTED_SEND_TO_EMAIL_COUNTRIES.include?(country)
      end
    end
    !unwanted
  end

  def send_confirmation_notification?
    !Rails.env.test? && confirmation_required? && !confirmed? && super
  end

  def legacy?
    ioffer_user.try(:legacy?)
  end

  def has_role_of_name?(name)
    role_users.collect(&:role_id).include?( Spree::Role.fetch_cached_role(name)&.id )
  end

  def admin?
    has_role_of_name?('admin')
  end

  def supplier_admin?
    has_role_of_name?('supplier_admin')
  end

  def approved_seller?
    has_role_of_name?('approved_seller')
  end

  def hp_seller?
    has_role_of_name?('hp_seller')
  end
  alias_method :hand_picked_seller?, :hp_seller?

  def pending_seller?
    has_role_of_name?('pending_seller')
  end

  def phantom_seller?
    has_role_of_name?('phantom_seller')
  end

  def quarantined_user?
    has_role_of_name?('quarantined_user')
  end
  alias_method :quarantined?, :quarantined_user?

  def seller?
    @is_seller ||= (self.role_users.collect(&:role_id) & Spree::Role.seller_roles.collect(&:id) ).size > 0
  end

  def full_seller?
    self.class::ACCEPTED_COUNTRIES_FOR_FULL_SELLER.include?(country&.downcase)
  end
  alias_method :in_source_country?, :full_seller?

  def buyer?
    role_users.blank? # !seller? && !admin?
  end

  def test_user?
    role_users.collect(&:role_id).include?(Spree::Role.test_user_role.id)
  end

  def fake_user?
    role_users.collect(&:role_id).include?(Spree::Role.fake_user_role.id)
  end

  ##
  # unreal_users include phantom
  def test_or_fake_user?
    ( role_users.collect(&:role_id) & Spree::Role.unreal_user_roles.collect(&:id) ).size > 0
  end

  ##
  # Test or fake user can still test doing real posting, orders, but not phantom
  def test_or_fake_user_except_phantom?
    ( role_users.collect(&:role_id) & Spree::Role.unreal_user_roles_except_phantom.collect(&:id) ).size > 0
  end

  def with_test_email?(which_attribute = :email)
    self.respond_to?(which_attribute) ? Spree::User.is_test_email?(self.send(which_attribute) ) : false
  end

  def ability
    @ability ||= Spree::Ability.new(self)
  end

  def has_ordered_product?(product_id)
    self.ordered_variants.select('product_id').collect(&:product_id).include?(product_id)
  end

  def too_many_orders_recently?
    conditions_met = [
      [Spree::Order::TIME_LIMIT_UNDER_REVIEW_1, Spree::Order::MAX_ORDERS_BEFORE_LOCKOUT_1],
      [Spree::Order::TIME_LIMIT_UNDER_REVIEW_2, Spree::Order::MAX_ORDERS_BEFORE_LOCKOUT_2]
    ]

    conditions_met.any? do |time_limit, max_orders|
      Spree::Order.complete.where(user_id: id, completed_at: time_limit.ago..Time.current).count >= max_orders
    end
  end

  ########################
  # Seller

  ##
  # @return [ActiveRecord::Relation]
  def completed_orders_with_complaints(extra_where = nil)
    completed_orders.joins(:complaint).where("#{User::Message.table_name}.recipient_user_id=?", id).where(extra_where)
  end

  ##
  # Really count of orders w/ complaints
  def count_of_order_complaints(extra_where = nil)
    completed_orders_with_complaints(extra_where).count
  end

  def recent_count_of_order_complaints(from_time = nil)
    from_time = 7.days.ago
    count_of_order_complaints(["#{::User::Message.table_name}.created_at > ? AND `references` IN (?)", from_time, User::OrderComplaint.payment_complaint_references])
  end

  CRITICAL_MINIUM_COUNT_OF_PAID_NEED_TRACKING = 2

  ##
  # This might change in future, not only Paypal
  def calculate_count_of_paid_need_tracking_not_responded(store_payment_method = nil)
    store_payment_method ||= store&.paypal_store_payment_method
    if store_payment_method
      store_payment_method&.orders_with_paid_need_tracking_of_same_payment_method_account&.count.to_i
    else
      0
    end
  end

  #
  # Dependent count_of_paid_need_tracking
  # @cnt [Integer] provide count ahead if already calculated
  def should_require_critical_response?(cnt = nil)
    cnt ||= self.count_of_paid_need_tracking&.value
    cnt ||= self.calculate_count_of_paid_need_tracking_not_responded
    cnt.to_i >= CRITICAL_MINIUM_COUNT_OF_PAID_NEED_TRACKING
  end

  ##
  # Depends on the User::Stat
  def required_critical_response?
    !required_critical_response.nil?
  end

  ##
  # @return Array of [User::OrderComplaint]
  def order_complaints
    completed_orders_with_complaints.includes(:complaint).collect(&:complaint)
  end

end
