class Retail::Store < ApplicationRecord
  self.table_name = 'retail_stores'

  validates_presence_of :retail_site_id

  attr_accessor :count_of_retail_products

  belongs_to :retail_site, class_name: 'Retail::Site', foreign_key: 'retail_site_id'
  has_one :store_to_spree_user, class_name: 'Retail::StoreToSpreeUser', foreign_key: 'retail_store_id'
  has_one :spree_user, class_name: 'Spree::User', through: :store_to_spree_user
  
  has_one :spree_user_migration, class_name: 'Retail::StoreToSpreeUser', foreign_key: 'retail_store_id'
  has_one :spree_user, class_name: 'Spree::User', foreign_key:'spree_user_id', through: :spree_user_migration

  before_validation :normalize_attributes


  def display_name
    [name, retail_site_store_id].join(' ')
  end

  def json_for_export
    as_json(only: [:name, :store_url, :retail_site_store_id] )
  end

  ################################################
  # Class methods

  # @return <Retail::Store> could be nil
  def self.find_or_build_retail_store(retail_site_id, agent, mechanize_page = nil)
    store_attr = agent.find_retail_store_attributes(mechanize_page || agent.current_page)
    store = nil
    if store_attr.size > 0
      store = self.where(retail_site_id: retail_site_id, retail_site_store_id: store_attr[:retail_site_store_id] ).last
      store ||= self.new( store_attr.merge(retail_site_id: retail_site_id) )
    end
    store
  end

  def self.find_or_create_retail_store(retail_site_id, agent, mechanize_page = nil)
    store = find_or_build_retail_store(retail_site_id, agent, mechanize_page)
    store.save if store && store.new_record?
    store
  end

  ##
  # Currently handling only iOffer, Aliexpress and Dhgate.  Add more rules if others.
  def self.make_store_url(site_name, store_id)
    case site_name.downcase
      when 'ioffer'
        "www.ioffer.com/stores/#{store_id}"
      else
        "www.#{site_name}.com/store/#{store_id}"
    end
  end

  ##################################
  #

  ##
  # Find the make the mapping of StoreToSpreeUser to Spree::User and Spree::Store.
  # @return <Spree::User> w/ its Spree::Store created.
  def setup_spree_user_and_store!
    store_to_spree_user = ::Retail::StoreToSpreeUser.where(retail_store_id: id).first
    spree_user = store_to_spree_user.try(:spree_user)
    unless spree_user
      fixed_username = retail_site_store_id
      if fixed_username.match(/\A\D+/).nil?
        fixed_username = nil # "#{retail_site.name.downcase.gsub(/(\W+)/, '')}#{fixed_username}"
      end
      spree_user = ::Spree::User.find_or_create_by(email: "#{retail_site_store_id}@shoppn.com") do|r|
        r.attributes = { login: retail_site_store_id, username: fixed_username, country: 'United States', country_code: 'US' }
        r.password = 'grabbedseller'
      end
    end
    spree_user.store ||= spree_user.create_store!

    store_to_spree_user ||= ::Retail::StoreToSpreeUser.find_or_initialize_by(
      retail_store_id: id)
    # old mapping broken
    store_to_spree_user.spree_user_id ||= spree_user.id 
    store_to_spree_user.retail_site_id ||= retail_site_id
    store_to_spree_user.save
    spree_user
  end

  private
  
  def normalize_attributes
    self.store_url = self.class.make_store_url(retail_site.name, retail_site_store_id)
    self.store_url.gsub!(/^((https?:)?\/\/)/i, '') if store_url
  end

end