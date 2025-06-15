module Spree::UserDecorator

  USERNAME_REGEXP = /\A[a-z][a-z0-9_\-]*\Z/i unless const_defined?(:USERNAME_REGEXP)
  COUNTRY_BASED_EMAIL_REGEXP_MAP = {
    /@((163|sina|sohu|yeah)\.net|(126|163|21cn|aliyun|chinaren|foxmail|qq|sina|sogou|sohu|tom|vip\.qq|vip\.sina|vip\.tom)\.(com|cn|com\.cn|com\.hk)|yahoo\.com\.(cn|hk)|ioffer\.wecom\.work)\Z/i => 'china',
    /.+\+(china|hk).+@gmail\.com\Z/i => 'china'
  } unless const_defined?(:COUNTRY_BASED_EMAIL_REGEXP_MAP)
  ACCEPTED_COUNTRIES_FOR_FULL_SELLER = ['china', 'hong kong', 'vietnam', 'thailand'].freeze unless const_defined?(:ACCEPTED_COUNTRIES_FOR_FULL_SELLER)
  ACCEPTED_COUNTRIES_FOR_BUYER_REGEXP = /\b(spain)\b/i.freeze unless const_defined?(:ACCEPTED_COUNTRIES_FOR_BUYER_REGEXP)
  UNACCEPTED_COUNTRIES_FOR_FULL_SELLER = %w(india).freeze unless const_defined?(:UNACCEPTED_COUNTRIES_FOR_FULL_SELLER)
  UNACCEPTED_COUNTRIES_FOR_BUYER = ['italy', 'france', 'india'].freeze unless const_defined?(:UNACCEPTED_COUNTRIES_FOR_BUYER)

  TIME_MARK_BEING_ACTIVE = 30.days unless const_defined?(:TIME_MARK_BEING_ACTIVE)
  MINIMUM_GOOD_STANDING_SELLER_BASED_SORT_RANK = 90000 unless const_defined?(:MINIMUM_GOOD_STANDING_SELLER_BASED_SORT_RANK)
  BASE_PENDING_SELLER_RANK = 500000 unless const_defined?(:BASE_PENDING_SELLER_RANK)
  BASE_PHANTOM_SELLER_RANK = 5000000 unless const_defined?(:BASE_PHANTOM_SELLER_RANK)
  MINIMUM_SELLER_BASED_SORT_RANK_FOR_ADOPTION = BASE_PENDING_SELLER_RANK unless const_defined?(:MINIMUM_SELLER_BASED_SORT_RANK_FOR_ADOPTION)

  #######################################

  module ClassMethods
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      if login = conditions.delete(:login)
        where(conditions.to_h).where(['lower(username) = :value OR lower(email) = :value', { :value => login.downcase }]).first
      elsif conditions.has_key?(:username) || conditions.has_key?(:email)
        where(conditions.to_h).first
      end
    end

    ##
    # Can have multiple admins
    def admins
      users = class_variable_get(:@@all_admins)
      unless users
        users = Spree::User.joins(:role_users).where(Spree::RoleUser.table_name => { role_id: Spree::Role.admin_role.id } ).all.to_a
        class_variable_set(:@@all_admins, users)
      end
      users
    end

    def fetch_admin
      admin_user = class_variable_get(:@@admin_user)
      return admin_user if admin_user
      admin_role = ::Spree::Role.includes(:users).find_or_create_by(name: 'admin')
      admin_user = admin_role.users.order('id desc').first
      unless admin_user
        admin_user = ::Spree::User.new(email: 'admin@shoppn.com', login: 'admin@shoppn.com', country:'United States',
              country_code: 'US', zipcode: '19019', timezone: '-04:00', spree_api_key: '' )
        admin_user.password = 'Mar$ket2020'
        admin_user.save
      end
      unless admin_user.role_users.where(role_id: admin_role.id).first
        admin_user.role_users.create(role_id: admin_role.id)
      end
      class_variable_set(:@@admin_user, admin_user)
      admin_user
    end

    def non_buyer_roles
      Spree::Role.non_buyer_roles
    end

    ##
    # @return [Array of Spree::Role]
    def seller_roles
      Spree::Role.seller_roles
    end

    def is_test_email?(email)
      !( email =~ /\Aneil[\-\.]?hussain/i || email =~ /(shoppn|ioffer)\.com\Z/ ).nil?
    end

    def matching_countries_for_email(email)
      matches = []
      Spree::User::COUNTRY_BASED_EMAIL_REGEXP_MAP.each_pair do|email_regex, country|
        if email_regex.match(email)
          matches << country
        end
      end
      matches
    end
  end

  #######################################

  def self.prepended(base)
    base.extend(ClassMethods)
    base.include(Spree::User::Accessors)
    base.include(Spree::User::ExtendedScopes)
    base.include(Spree::User::LocaleHelper)
    base.include(Spree::User::Actions)
    base.include(::User::StatAccessors)

    base.validates :username, format:{ with: USERNAME_REGEXP, message:'only alphabets and numbers'}, allow_blank: true
    base.validates_uniqueness_of :username, message: I18n.t('errors.user.username_taken'),
      if: Proc.new{|u| u.username.present? }


    #################
    # Callback

    base.before_save :set_defaults
    base.after_create :create_store!
    base.before_update :update_other_data!
    base.after_save :calculate_stats! # call to RoleUser#after_destroy not called

    base.alias_attribute :npb_count, :non_paying_buyer_count
    base.attr_accessor :skip_calculate_stats

    base.class_variable_set :@@all_admins, nil
    base.class_variable_set :@@admin_user, nil

    base.whitelisted_ransackable_attributes += ['username', 'created_at', 'last_sign_in_at',
      'current_sign_in_at', 'current_sign_in_ip', 'last_active_at', 'last_email_at', 'seller_rank',
      'count_of_products_created', 'count_of_products_adopted', 'count_of_transactions' ]
    base.whitelisted_ransackable_associations += ['store', 'ioffer_user', 'retail_store_to_user', 'user_list_users', 'role_users', 'user_stats', 'count_of_paid_need_tracking']

    base.ransack_alias :gms, :ioffer_user_gms
    base.ransack_alias :retail_site_id, :retail_store_to_user_retail_site_id

    # base.handle_asynchronously :send_confirmation_instructions, queue: 'user' # delayed_job

    base.delegate :store_payment_methods, :payment_methods, to: :fetch_store

    #################

    base.handle_asynchronously :send_confirmation_instructions, priority: 1, queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE if Rails.env.production?

  end

  ######################################
  # Action methods

  # Find or create one
  def fetch_store
    @store ||= self.store || create_store!
  end

  def create_store!
    user_store = ::Spree::Store.find_or_initialize_by(user_id: id) do|store|
      store.name = display_name || username || "Store #{id}"
      store.url = APP_HOST # ::SolidusMarket::Application.routes.url_helpers.seller_path(id: id)
      store.mail_from_address = email
      store.code = "sellers/#{id}"
    end
    user_store.save
    user_store
  end

    ##
  # Check to see need to create seller roles ahead.
  # Only needs to be called once after registration.
  def create_roles!
    role = Spree::Role.find_or_create_by(name: legacy? ? 'approved_seller' : 'pending_seller')
    self.save if id.nil? # some case would raise parent not save for call below
    self.role_users.find_or_create_by(role_id: role.id)
  end


  ##
  # Create ioffer_create if necessary.
  def ensure_ioffer_user!
    if ioffer_user.nil? && username.present? # ioffer.username is required
      self.ioffer_user = Ioffer::User.create(username: username, email: email, user_id: id)
    else
      ioffer_user
    end
  end

  ##
  # Calculation only and return value only, not set or saved.
  def calculate_seller_rank(ignore_current_seller_rank = false)
    return seller_rank if !ignore_current_seller_rank && seller_rank.to_i < 0 && seller_rank.to_i > 5500666
    v = 0
    if phantom_seller?
      v = BASE_PHANTOM_SELLER_RANK
    elsif hp_seller?
      v += 9000000
    elsif legacy?
      v += 1000005
    elsif approved_seller?
      v += 1000000
    elsif full_seller? # prioritized countries
      v += 900000
    elsif pending_seller?
      v += 500000
    end
    if v > 0
      paypal = Spree::PaymentMethod.paypal
      store_payment_method_ids = store ? store.store_payment_methods.collect(&:payment_method_id) : []
      if store_payment_method_ids.include?(paypal.id)
        v += 90000
      elsif store_payment_method_ids.size > 0
        v += 50000
      end
    end
    v
  end



  protected

  def set_defaults
    self.login = username if username.present?
    set_country_data
  end

  def set_country_data
    if country.blank?
      COUNTRY_BASED_EMAIL_REGEXP_MAP.each_pair do|r, _country|
        self.country = _country if r =~ email
      end
    end
    self.country_code ||= country&.to_country_code
  end

  # This causes the problem when calling user.really_destroy!: RuntimeError: Can't modify frozen hash.
  # Ridiculous: already calling to really_destroy!, actually from database, still doing self.save
  def scramble_email_and_password
  end

  def update_other_data!
    if current_sign_in_at_changed?
      RequestLog.create(user_id: id, group_name:'sign_in',
        ip: last_sign_in_ip
      )
      self.current_sign_in_at = Time.now
      self.current_sign_in_ip = current_sign_in_ip
    end
  end
end

::Spree::User.prepend Spree::UserDecorator if ::Spree::User.included_modules.exclude?(Spree::UserDecorator)
