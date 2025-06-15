module Spree::OrderDecorator
  def self.prepended(base)
    base.extend ClassMethods
    base.include ::Spree::Order::Actions
    base.include ::Spree::UserRelatedScopes

    base.const_set 'AUTO_SELECT_SHIPPING_METHOD', true
    base.const_set 'PAID_PAYMENT_STATES', %w(paid credit_owed)
    base.const_set 'TIME_LIMIT_UNDER_REVIEW_1', 7.days
    base.const_set 'MAX_ORDERS_BEFORE_LOCKOUT_1', 10
    base.const_set 'TIME_LIMIT_UNDER_REVIEW_2', 1.days
    base.const_set 'MAX_ORDERS_BEFORE_LOCKOUT_2', 5

    base.attr_reader :proof_of_payment
    base.mount_uploader :proof_of_payment, ::ImageUploader

    base.alias_method :buyer, :user

    base.belongs_to :seller, -> { with_deleted }, class_name:'Spree::User', foreign_key:'seller_user_id'

    base.whitelisted_ransackable_attributes << 'seller_user_id'
    base.whitelisted_ransackable_associations += ['seller', 'complaint', 'count_of_paid_need_tracking']

    base.before_update :create_message!

    base.has_many :messages, -> { where(record_type:'Spree::Order') }, class_name:'User::Message', foreign_key: 'record_id'
    base.has_one :one_message, -> { where(record_type:'Spree::Order') }, class_name:'User::Message', foreign_key: 'record_id'

    base.has_one :report, -> { where("record_type='Spree::Order' AND level >= #{User::Message::COMPLAINT_LEVEL}") }, class_name:'User::Message', foreign_key: 'record_id'

    base.has_one :complaint, -> { where("record_type='Spree::Order' AND type IN (?)", %w(User::OrderComplaint)) }, class_name:'User::Message', foreign_key: 'record_id'
    base.has_one :provided_tracking_number, -> { where("record_type='Spree::Order' AND type IN (?)", %w(User::OrderProvidedTrackingNumber User::OrderCorrectedTrackingNumber)) }, class_name:'User::Message', foreign_key: 'record_id'
    base.has_one :need_tracking_number, -> { where("record_type='Spree::Order' AND type IN (?)", %w(User::OrderNeedTrackingNumber User::OrderBrokenTrackingNumber)) }, class_name:'User::Message', foreign_key: 'record_id'

    base.has_one :count_of_paid_need_tracking, -> { where(name: ::Spree::User::COUNT_OF_PAID_NEED_TRACKING) }, class_name:'User::Stat', primary_key: 'seller_user_id', foreign_key: 'user_id'

    ##
    # Had checked out but not canceled or paid.
    base.scope :complete_but_not_finished, -> { where("completed_at is not null and canceled_at is null and  approved_at is null and payment_state IN ('balance_due', 'credit_owed')") }

    base.scope :sold_by_phantom_sellers, -> { with_role_ids( [Spree::Role.phantom_seller_role.id], 'seller_user_id' ) }
    base.scope :not_sold_by_phantom_sellers, -> { without_role_ids( [Spree::Role.phantom_seller_role.id], 'seller_user_id' ) }

    base.scope :not_bought_by_unreal_users, -> { without_role_ids(Spree::Role.unreal_user_role_ids, 'user_id') }

    base.scope :with_product_id, ->(product_id) { not_bought_by_unreal_users.joins(:line_items).where("#{Spree::LineItem.table_name}.product_id=#{product_id}") }

    base.scope :with_complaint, -> { joins(:complaint).where("#{User::Message.table_name}.deleted_at IS NULL") }
    base.scope :with_need_tracking_number, -> { joins(:need_tracking_number).where("#{User::Message.table_name}.deleted_at IS NULL") }
    base.scope :with_provided_tracking_number, -> { joins(:provided_tracking_number) }
    base.scope :without_complaint_or_tracking_number, -> { where("highest_message_level <= #{User::Message::ORDER_LEVEL + 100}") }
    base.scope :paid_need_tracking, -> { joins(:need_tracking_number).where("#{User::Message.table_name}.deleted_at IS NULL AND image IS NOT NULL") }
    base.scope :paid_need_tracking_not_responded, -> { paid_need_tracking.where("#{User::Message.table_name}.last_viewed_at IS NULL") }
    base.scope :order_by_paid_need_tracking, -> { joins(:count_of_paid_need_tracking).order("#{::User::Stat.table_name}.value DESC") }
    base.scope :with_reports, -> { where("highest_message_level >= #{User::Message::COMPLAINT_LEVEL}") }

    # No report
    base.scope :with_comments, -> {
      where("highest_message_level BETWEEN #{User::Message::ORDER_LEVEL} AND #{User::Message::COMPLAINT_LEVEL - 1}")
    }

    #

    # base.addition_to_state_machine
  end

  module ClassMethods
    def accessible_by(ability, action)
      if ability.public_action?(action) || ability.user&.admin?
        self.where(nil)
      else
        self.where('user_id=?', ability.user.id)
      end
    end

    ##
    #
    def addition_to_state_machine
      self.insert_checkout_step :wait_for_offer, before: :complete
      m = self.state_machine
      m.event :wait_for_offer do
        transition to: :wait_for_offer,
          from: [:payment, :confirm], if: :is_phantom_seller?
      end
      m.before_transition to: :complete, do: :ensure_not_phantom_seller

    end

    def row_header
      Spree::LineItem.row_header + ['Transaction time', 'Order ID', 'Order number', 'Seller ID', 'Seller Email', 'Total Price',
        'Payment Type', 'Paypal Account ID', 'Buyer ID']
    end
  end

  #####################
  # Overrides

  def checkout_steps
    @checkout_steps ||= super
  end

  def collect_payment_methods(store = nil)
    logger.debug "| collect_payment_methods w/ store #{store}"
    Spree::PaymentMethod.selectable_for_store(store&.id).available_on_front_end.distinct.select { |pm| pm.available_for_order?(self)  }
  end

  ##
  # Extra check to @collect_payment_methods even w/ self.store
  def available_payment_methods(store = nil)
    @available_payment_methods ||= collect_payment_methods(store || self.store)
  end

  ##
  # To create message, need extra among original's update_columns call
  def approved_by(user)
    transaction do
      approve!
      update(approver_id: user.id, approved_at: Time.current, payment_state:'paid')
    end
  end

  ##
  # When order parameters all combined into one instead of sequential steps,
  # would break it up and call update in same sequence as Spree's original.
  # The transitions in between states have checks and updates done inside
  # CheckoutController
  def update_all_from_params(params, permitted_params, request_env = {})
    return false if params[:order].nil?
    payments_attributes = params[:order].delete(:payments_attributes)
    proceed_all_the_way = !payments_attributes.nil?

    success_returns = []
    success_returns << update_from_params(params, permitted_params, request_env)
    unless success_returns.last
      logger.debug "** Error going from #{state} to next: #{self.errors.messages}"
    end
    if ship_address && (state == 'address' || can_go_to_state?('address') )
      self.state ||= 'address'
      self.save
      create_proposed_shipments
      if Spree::Order::AUTO_SELECT_SHIPPING_METHOD
        set_shipments_cost
        create_shipment_tax_charge!
        create_tax_charge!
      end
    end

    if shipments.any? && can_go_to_state?('delivery')
      self.state = 'delivery'
      increment!(:state_lock_version)
      self.save

      selected_shipping_method_id =
        (Spree::Order::AUTO_SELECT_SHIPPING_METHOD && Spree::ShippingMethod.standard_delivery&.id) ||
        params[:order][:selected_shipping_rate_id] # this should be buyer preference
      params[:order][:shipments_attributes] ||= []

      shipments.each_with_index do|shipment, index|
        selected_shipping_rate_id = shipment.shipping_rates.find{|rate| selected_shipping_method_id ? rate.shipping_method_id == selected_shipping_method_id : rate.cost.to_f == 0.0 }
        params[:order][:shipments_attributes] = {
            index => {
              selected_shipping_rate_id: selected_shipping_rate_id, id: shipment.id }
          }
      end

      success_returns << update_from_params(params, permitted_params, request_env)
      if success_returns.last
        self.state = 'payment'
        increment!(:state_lock_version)
        self.save
      else
        logger.debug "** Error going from #{state} to next: #{self.errors.messages}"
      end
    end
    if payments_attributes && proceed_all_the_way && (state == 'payment' || can_go_to_state?('payment'))

      params[:order].delete(:shipments_attributes)
      params[:order][:payments_attributes] = payments_attributes

      success_returns << update_from_params(params, permitted_params, request_env)
      if success_returns.last
        self.state = 'complete'
        self.completed_at = Time.now
        self.state_lock_version = 4
        self.save
        self.update_products!
        self.notify_users
      else
        logger.debug "** Error going from #{state} to next: #{self.errors.messages}"
      end
    end
    success_returns.all?
  end


  def deliver_order_confirmation_email
    notify_users
  end
=begin
  def checkout_allowed?
    super && seller&.ability.try(:can?, :sales, ::Spree::Order)
  end

  def ensure_line_items_are_in_stock
    if !seller&.ability.try(:can?, :sales, ::Spree::Order)
      # warning but not reset
      errors.add(:base, I18n.t('errors.order.seller_out_of_stock'))
      false
    elsif insufficient_stock_lines.present?
      restart_checkout_flow
      errors.add(:base, Spree.t(:insufficient_stock_lines_present))
      false
    else
      true
    end
  end
=end

  #####################
  # New attributes

  def as_json(options = {})
    h = super(options)
    h['line_items'] = line_items.collect(&:as_json)
    h
  end

  def to_s
    h = attributes.slice('id', 'number', 'user_id', 'store_id', 'seller_user_id', 'state')
    h[:line_items] = line_items.collect(&:to_s)
    h.as_json.to_s
  end

  def to_row
    return @row_values if @row_values
    # ['Transaction time', 'Order ID', 'Order number', 'Seller ID', 'Seller Email', 'Total Price', 'Payment Type', 'Paypal Account ID', 'Buyer ID']
    @row_values = []
    base_order_row_values = [
      timestamp_with_slashes(completed_at), id, number, seller_user_id, seller&.email,
      total.to_f, payments.first&.payment_method&.description,
      seller&.store ? seller.store.account_parameters_of(Spree::PaymentMethod.paypal.id).try(:[], 'account_id') : '', user_id
    ]
    line_items.includes(product:[:taxons]).each do|li|
      @row_values << ( li.to_row + base_order_row_values )
    end
    @row_values
  end

  ##
  # Used to be an attribute.
  def store_id
    store&.id
  end

  ##
  # For page title or label in list
  def title
    "Order #{number} - #{store.name}"
  end

  def the_other_user_id(current_user_id)
    current_user_id == seller_user_id ? user_id : seller_user_id
  end

  ##
  # Of valid payments
  def latest_payment_method
    payments.valid.last&.payment_method
  end

  ##
  # The spree_shipments.number is auto generated alphanum.
  def latest_tracking_number
    shipments.last&.tracking
  end

  def has_unresponded_message_of?(message_classes = [])
    !messages.not_viewed.find{|m| message_classes.any?{|c| m.is_a?(c) } }.nil?
  end

  def requested_tracking?
    messages.where(type:'User::OrderNeedTrackingNumber').count > 0
  end

  def claimed_broken_tracking?
    messages.where(type:'User::OrderBrokenTrackingNumber').count > 0
  end

  def find_or_create_guest_token
   self.guest_token ||= SecureRandom.urlsafe_base64
   save if guest_token_changed?
   guest_token
  end

  # Regardless viewed or not
  def buyer_requested_help?
    message_classes = [User::OrderHelpWithPayment, User::OrderNeedTrackingNumber, User::OrderBrokenTrackingNumber]
    found_m = messages.find{|m| message_classes.any?{|c| m.is_a?(c) } }
    !found_m.nil?
  end

  # Regardless viewed or not
  def buyer_claimed_already_paid?
    message_classes = [User::OrderNeedTrackingNumber, User::OrderBrokenTrackingNumber]
    found_m = messages.find{|m| message_classes.any?{|c| m.is_a?(c) } }
    found_m ||= messages.find{|m| m.is_a?(User::OrderComplaint) && m.references == 'order_already_paid' }
    !found_m.nil?
  end

  ##
  # @return [Hash of payment_method_id[Integer] => Spree::StorePaymentMethod]
  def store_payment_methods
    h = Spree::StorePaymentMethod.where(store_id: store_id).all.group_by(&:payment_method_id)
    h.each_pair do|k, v|
      h[k] = v.first if v.is_a?(Array)
    end
    h
  end

  def line_item_of_product(product_id)
    line_items.find{|li| li.product_id == product_id }
  end

  def line_item_of_variant(variant_id)
    line_items.find{|li| li.variant_id == variant_id }
  end

  def line_item_of_variant_adoption(variant_adoption_id)
    line_items.find{|li| li.variant_adoption_id == variant_adoption_id }
  end

  def is_phantom_seller?
    seller&.phantom_seller?
  end

  def ensure_not_phantom_seller
    if is_phantom_seller?
      wait_for_offer
      false
    else
      true
    end
  end

end

Spree::Order.prepend(Spree::OrderDecorator) if Spree::Order.included_modules.exclude?(Spree::OrderDecorator)
