module Spree::User::ExtendedScopes
  extend ActiveSupport::Concern

  included do
    # Associations
    has_one :role_user, class_name:'Spree::RoleUser'
    has_one :ioffer_user, foreign_key: 'user_id', class_name:'Ioffer::User'
    delegate :transactions_count, :items_count, :positive, :negative, :gms, :rating, to: :ioffer_user, allow_nil: true

    has_many :other_site_accounts, class_name:'Retail::OtherSiteAccount'
    has_one :store, class_name: 'Spree::Store', foreign_key: 'user_id', dependent: :destroy

    has_one :retail_store_to_user, class_name:'Retail::StoreToSpreeUser', foreign_key:'spree_user_id'
    has_one :retail_store, class_name: 'Retail::Store', through: :retail_store_to_user
    has_one :retail_site, class_name: 'Retail::Site', through: :retail_store_to_user

    # Seller associations
    has_many :products
    has_many :variants

    has_many :user_selling_taxons
    has_many :selling_taxons, through: :user_selling_taxons, class_name:'Spree::Taxon', source:'taxon'

    has_many :user_selling_option_values
    has_many :selling_option_values, through: :user_selling_option_values, class_name:'Spree::OptionValue', source:'option_value'

    has_many :selling_orders, class_name:'Spree::Order', foreign_key:'seller_user_id', dependent: :destroy
    has_many :completed_orders, -> { complete }, class_name:'Spree::Order', foreign_key:'seller_user_id', dependent: :destroy
    has_many :user_stats, class_name:'User::Stat', foreign_key:'user_id', dependent: :destroy

    has_one :count_of_paid_need_tracking, -> { where(name: ::Spree::User::COUNT_OF_PAID_NEED_TRACKING) },class_name:'User::Stat', foreign_key:'user_id'
    has_one :required_critical_response, -> { where(name: ::Spree::User::REQUIRED_CRITICAL_RESPONSE) },class_name:'User::Stat', foreign_key:'user_id'

    # Buyer associations
    has_many :orders
    has_many :line_items, through: :orders
    has_many :ordered_variants, class_name:'Spree::Variant', through: :line_items, source: :variant

    has_many :request_logs
    has_many :sign_in_request_logs, -> { on_sign_in.order('id desc') }, class_name:'RequestLog'

    has_many :user_list_users
    has_many :user_lists, through: :user_list_users


    #################
    # Scopes

    scope :no_email_sent, -> { where('last_email_at IS NULL') }
    scope :should_get_email, -> { where('last_email_at IS NULL AND email_trial_count < 3') }

    # NOT IN non_buyer_roles not accurate as there's no "buyer" role
    scope :buyers, -> { joins("LEFT JOIN #{Spree::RoleUser.table_name} ON #{Spree::User.table_name}.id=#{Spree::RoleUser.table_name}.user_id").where("spree_role_users.user_id is null") }

    scope :sellers, -> { with_role_ids( Spree::User.seller_roles.collect(&:id) ) }
    scope :real_sellers, -> { with_role_ids( Spree::Role.real_seller_roles.collect(&:id) ) }
    
    # Only inclusive won't work because possible quarantined_user has original seller role also.
    scope :viable_sellers, -> { where("seller_rank >= ?", Spree::User::BASE_PENDING_SELLER_RANK).without_role_ids(Spree::Role.unreal_user_role_ids ) }
    scope :only_active_sellers, -> { sellers.where("last_active_at > ?",Spree::User::TIME_MARK_BEING_ACTIVE.ago) }

    scope :real_users, -> { without_role_ids(Spree::Role.unreal_user_role_ids) }
    scope :unreal_users, -> { with_role_ids(Spree::Role.unreal_user_role_ids) }
    scope :phantom_sellers, -> { (ulist = Spree::UserList.find_by(name:"Phantom Only Sellers")) ? 
      joins(:user_list_users).where("#{Spree::UserListUser.table_name}.user_list_id=#{ulist.id}") :
      with_role_ids([ Spree::Role.phantom_seller_role.id ]) 
    }

    # User roles: from user_related_scopes
    scope :with_role_ids, lambda{|role_ids, user_id_attr = nil| joins("inner join #{Spree::RoleUser.table_name} on #{self.table_name}.#{user_id_attr || 'id'}=#{Spree::RoleUser.table_name}.user_id").where("#{Spree::RoleUser.table_name}.role_id IN (?)", role_ids) }
    scope :without_role_ids, lambda{|role_ids, user_id_attr = nil| joins("LEFT JOIN #{Spree::RoleUser.table_name} ON #{self.table_name}.#{user_id_attr || 'id'}=#{Spree::RoleUser.table_name}.user_id AND #{Spree::RoleUser.table_name}.role_id IN (#{role_ids.collect(&:to_s).join(',')})").where("#{Spree::RoleUser.table_name}.user_id IS NULL") }

    scope :no_role_or_without_roles, lambda {|role_ids| 
      joins("LEFT JOIN #{Spree::RoleUser.table_name} ON #{Spree::User.table_name}.id=#{Spree::RoleUser.table_name}.user_id").where("#{Spree::RoleUser.table_name}.role_id is null or #{Spree::RoleUser.table_name}.role_id NOT IN (?)", role_ids)
    }
    scope :except_fake_users, -> { no_role_or_without_roles( [::Spree::Role.fake_user_role&.id] ) }
    scope :except_unreal_users, -> { no_role_or_without_roles( ::Spree::Role.unreal_user_role_ids ) }

    # Status
    scope :never_signed_in, -> { where('current_sign_in_at is null') }
    scope :eligible_for_phantom_users, -> { joins(:ioffer_user).except_unreal_users.never_signed_in.where('gms < 2000').distinct }

    scope :has_created_products, -> { has_created_which(Spree::Product) }
    scope :has_created_variants, -> { has_created_which(Spree::Variant) }
    scope :has_created_which, lambda {|record_class| joins("LEFT JOIN #{record_class.table_name} ON #{Spree::User.table_name}.id=#{record_class.table_name}.user_id").where("#{record_class.table_name}.id is not null") }
  end

  class_methods do
    ##
    # @return [ActiveRecord_Relation]
    def pick_phantom_sellers(how_many = 1, exclude_user_ids = [])
      more_q = Spree::User.phantom_sellers.
        order('RAND() ASC').limit( [1, how_many - exclude_user_ids.size].max )
      if exclude_user_ids.size > 0
        more_q = more_q.where("#{Spree::User.table_name}.id NOT IN (?)", exclude_user_ids )
      end
      more_q
    end
  end
end