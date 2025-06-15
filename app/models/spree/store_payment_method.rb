class Spree::StorePaymentMethod < ApplicationRecord
  belongs_to :store
  belongs_to :payment_method, class_name:'Spree::PaymentMethod'

  attr_accessor :account_id

  delegate :user_id, to: :store

  whitelisted_ransackable_attributes = %w(payment_method_id account_parameters instruction)

  validates_presence_of :store_id, :payment_method_id
  validate :check_account_info

  before_save :normalize_attributes
  after_create :ensure_same_ioffer_user_payment_method!
  after_save :update_seller_rank!
  after_destroy :update_seller_rank!

  SAVE_ACCOUNT_PARAMETERS_IN_HASH = false

  def account_hash
    if account_parameters.present? # old value might stil be in JSON format
      (account_parameters =~ /\A\{.*\}\Z/) ? JSON.parse(account_parameters) : { 'account_id' => account_parameters }
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end

  def account_id_in_parameters
    account_hash['account_id']&.strip
  end
  
  ##
  # If Ioffer::PaymentMethod has the same payment, create connection of 
  # Ioffer::User (Ioffer::UserPaymentMethod)
  def ensure_same_ioffer_user_payment_method!
    if (ioffer_payment_method = payment_method.same_ioffer_payment_method)
      if store.user # broken data if nil
        ioffer_user = store.user.ensure_ioffer_user!
        if ioffer_user
          ioffer_user.user_payment_methods.find_or_create_by(payment_method_id: ioffer_payment_method.id)
        end
      end
    end
  end

  def update_seller_rank!
    store.user&.schedule_to_calculate_stats!
  end

  def same_store_payment_methods
    Spree::StorePaymentMethod.includes(:store).
      where("payment_method_id=#{payment_method_id} AND (account_parameters='#{account_id_in_parameters&.strip}' OR account_parameters LIKE '%\"#{account_id_in_parameters&.strip}\"%')" )
  end

  #
  # @extra_where [] applied to Spree::Order query
  def orders_of_same_payment_method_account(extra_where = nil)
    seller_user_ids = same_store_payment_methods.collect(&:user_id)
    Spree::Order.complete.where(seller_user_id: seller_user_ids).where(extra_where).distinct("#{Spree::Order.table_name}.id")
  end

  def recent_orders_of_same_payment_method_account
    orders_of_same_payment_method_account(["#{Spree::Order.table_name}.completed_at > ?", 7.days.ago] )
  end

  ##
  # Use of orders_of_same_payment_method_account
  def orders_with_paid_need_tracking_of_same_payment_method_account
    orders_of_same_payment_method_account.paid_need_tracking_not_responded
  end

  def normalize_attributes
    if account_id.present?
      if SAVE_ACCOUNT_PARAMETERS_IN_HASH
        existing_h = account_hash
        existing_h['account_id'] = account_id.strip
        self.account_parameters = JSON.dump( existing_h )
      else
        self.account_parameters = account_id.strip
      end
    end
  end

  # Since account_parameters did not start has plain string of only email or username,
  # there's no validation of the field.  Now it's given that email validation via account_id.
  def check_account_info
    normalize_attributes

    # Selection of those provided
    if new_record? && account_id_in_parameters.blank?
      !payment_method_id.nil?
    elsif account_id_in_parameters.present?
      if ( self.same_store_payment_methods.collect(&:id) - [self.id].compact ).size > 0
        self.errors.add(:account_parameters, I18n.t('errors.store.payment_account_already_linked_to_another', payment_method: payment_method&.description || '').squish )
        false
      elsif account_id_in_parameters =~ URI::MailTo::EMAIL_REGEXP && !new_record? # might have migration problem
        true
      else
        true
      end
    else
      self.errors.add(:account_parameters, I18n.t('errors.user.invalid_email'))
      false
    end
  end

end
