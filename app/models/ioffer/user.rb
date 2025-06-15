class Ioffer::User < Spree::Base

  include Ioffer::EncryptionHelper

  devise :database_authenticatable, :recoverable

  END_OF_IMPORTED_USERS = Time.local(2020, 5, 8)

  USERNAME_REGEXP = /\A[\w\.\-_]+\Z/
  EMAIL_REGEXP = /\A[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\Z/i
  validates :email, :presence => true, :format => EMAIL_REGEXP
  validates_uniqueness_of :email, message: I18n.t('errors.user.email_taken')
  validates :username, format: USERNAME_REGEXP
  validates_uniqueness_of :username, message: I18n.t('errors.user.username_taken')
  validates :password, confirmation: true

  has_many :user_payment_methods, dependent: :delete_all
  has_many :payment_methods, through: :user_payment_methods

  has_many :user_categories, dependent: :delete_all
  has_many :categories, through: :user_categories

  has_many :user_brands, dependent: :delete_all
  has_many :brands, through: :user_brands

  has_many :other_site_accounts, dependent: :delete_all, class_name:'Retail::OtherSiteAccount'

  belongs_to :spree_user, foreign_key:'user_id', class_name:'Spree::User'

  scope :with_related_spree_user, -> { joins(:spree_user).where("#{Spree::User.table_name}.id IS NOT NULL") }
  scope :no_email_sent, -> { where('last_email_at IS NULL') }
  scope :should_get_email, -> { where('last_email_at IS NULL AND email_trial_count < 3') }
  scope :not_claimed, -> { where('reset_password_token IS NOT NULL') }
  scope :claimed, -> { where('reset_password_token IS NULL') }

  self.whitelisted_ransackable_associations = %w[spree_user other_site_accounts user_payment_methods payment_methods]
  self.whitelisted_ransackable_attributes = %w[username email location gms ip]

  @@encryption_key = nil

  before_save :encrypt_password
  before_validation :normalize_attributes
  after_create :convert!

  PERMITTED = [:username, :email, :password, :password_confirmation, :reset_password_token, :other_site_account_id]

  attr_accessor :password, :password_confirmation
  attr_writer :login

  def login
    @login || self.username || self.email
  end

  def positive_ratio
    positive.to_f / (positive + negative)
  end

  def claimed?
    username.present? && reset_password_token.blank?
  end

  def legacy?
    created_at < END_OF_IMPORTED_USERS
  end

  def sign_up_time
    created_at && created_at > END_OF_IMPORTED_USERS ? created_at : nil
  end

  ###############################
  # Actions

  ##
  # The public call to only regenerate reset_password_token and save w/o sending instructions.
  def reset_password_token!
    set_reset_password_token
  end


  ##
  # Find or create Retail::Store, connected Spree::User, and then Spree::Store, and then 
  # payment_methods, categories.
  # This calls the sequence of convert_to_retail_store!, convert_to_spree_user!, 
  # convert_payment_methods!, convert_categories! at last.
  # @return [Spree::User]
  def convert!
    rstore = convert_to_retail_store!
    
    rstore_conv = rstore.spree_user_migration

    spree_user = nil
    Spree::User.transaction do
      spree_user = rstore_conv.try(:spree_user) || convert_to_spree_user!
      rstore_conv = Retail::StoreToSpreeUser.find_or_create_by(retail_store_id: rstore.id, spree_user_id: spree_user.id)

      spree_user.store ||= spree_user.create_store!
    end

    convert_payment_methods!(spree_user) if spree_user

    convert_categories!(spree_user) if spree_user

    spree_user
  end

  #####################
  # Individual conversion methods

  ##
  # @return [Retail::Store]
  def convert_to_retail_store!
    ioffer = Retail::Site.find_by_name('ioffer')
    rstore = Retail::Store.find_or_initialize_by(retail_site_id: ioffer.id, retail_site_store_id: username) 
    rstore.store_url ||= "https://www.ioffer.com/stores/#{username}"
    rstore.name ||= username
    rstore.save

    rstore
  end

  def convert_other_site_accounts!(spree_user = nil)
    spree_user ||= convert_to_spree_user!
    other_site_accounts.collect do|other_site_account|
      site = Retail::Site.find_by_name(other_site_account.site_name)
      next if site.nil?
      rstore = Retail::Store.find_or_initialize_by(retail_site_id: site.id, retail_site_store_id: other_site_account.account_id) 
      rstore.name ||= other_site_account
      rstore.save
      rstore
    end
  end

  ADDRESS_REGEXP = /(?<zipcode>[\w\-]+),\s*(?<country>[a-z\s]+)\Z/i
  ##
  # @return [Spree::User] # 
  def convert_to_spree_user!
    user = username.present? ? Spree::User.find_or_initialize_by(username: username) : 
      Spree::User.find_or_initialize_by(email: email)
    user.login = username
    user.email = email
    user.display_name = name.try(:strip)
    begin
      user.password ||= self.class.decrypt(encrypted_password) if encrypted_password.present?
    rescue OpenSSL::Cipher::CipherError, IOError
      user.password ||= 'usertransfer00'
    end
    if address
      country_record = nil
      if (address_m = address.match(ADDRESS_REGEXP) )
        user.country = address_m[:country].strip
        country_record = ::Spree::Country.where(name: user.country).first
        user.country_code = country_record.try(:ios3)
        user.zipcode = address_m[:zipcode]
      end
    end
    user.save if user.new_record?
    self.spree_user = user
    self.update(user_id: user.id) if user.id

    user 
  end

  ##
  # @spree_user [Spree::User]
  def convert_categories!(spree_user = nil, erase_old = true)
    spree_user ||= convert_to_spree_user!
    ::Spree::UserSellingTaxon.where(user_id: spree_user.id).delete_all if erase_old && categories.present?
    categories.each do|ioffer_cat|
      ioffer_cat.category_to_taxons.each do|ct|
        selling = ::Spree::UserSellingTaxon.find_or_create_by(user_id: spree_user.id, taxon_id: ct.taxon_id)
      end
    end
  end

  ##
  # @spree_user [Spree::User]
  # @erase_all [Boolean] If true, this would entirely erase all Spree::StorePaymentMethod for the 
  #   user, which also includes the account parameters.  Otherwise, would only delete missing ones.
  def convert_payment_methods!(spree_user = nil, erase_all = false)
    return [] if payment_methods.blank?

    spree_user ||= convert_to_spree_user!
    
    # Erase equivalent Spree::PaymentMethod
    spree_pm_h = {}
    payment_methods.collect do|ioffer_pm|
      pm = ioffer_pm.same_spree_payment_method
      spree_pm_h[ioffer_pm.id] = pm.id
    end

    query = Spree::StorePaymentMethod.where(store_id: spree_user.fetch_store.id)
    query = query.where('payment_method_id NOT IN (?)', spree_pm_h.values) if !erase_all && spree_pm_h.size > 0
    query.delete_all

    payment_methods.collect do|ioffer_pm|
      if (pm_id = spree_pm_h[ioffer_pm.id] )
        Spree::StorePaymentMethod.find_or_create_by(store_id: spree_user.fetch_store.id, payment_method_id: pm_id)
      end
    end
  end

  private

  def encrypt_password
    if password
      self.encrypted_password = self.class.encrypt(password)
    end
  end

  def normalize_attributes
    self.address.gsub!(/(<\w+[^>]*\/?>)/, "\n") if address.present?
    self.name = name.titleize if name.present?
    if username
      self.username.strip! 
      unless username.blank? || username =~ USERNAME_REGEXP
        self.errors.add(:username, :invalid, message: I18n.t('user.provide_a_valid_username'))
      end
    end
  end

end