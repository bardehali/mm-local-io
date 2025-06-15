##
# For table that has user_id as creator.  These are the scopes in common.
module Spree::UserRelatedScopes
  extend ActiveSupport::Concern

  included do
    belongs_to :user, -> { with_deleted }, class_name: 'Spree::User'
    
    # User roles
    scope :with_role_ids, lambda{|role_ids, user_id_attr = nil, _table_name = nil| joins("inner join #{Spree::RoleUser.table_name} on #{_table_name || self.table_name}.#{user_id_attr || 'user_id'}=#{Spree::RoleUser.table_name}.user_id").where("#{Spree::RoleUser.table_name}.role_id IN (?)", role_ids) }
    scope :without_role_ids, lambda{|role_ids, user_id_attr = nil, _table_name = nil| joins("LEFT JOIN #{Spree::RoleUser.table_name} ON #{_table_name || self.table_name}.#{user_id_attr || 'user_id'}=#{Spree::RoleUser.table_name}.user_id AND #{Spree::RoleUser.table_name}.role_id IN (#{role_ids.collect(&:to_s).join(',')})").where("#{Spree::RoleUser.table_name}.user_id IS NULL") }

    scope :owned_by_users, lambda {|user_id_attr = nil, _table_name = nil| 
      with_role_ids(Spree::Role.active_user_role_ids, user_id_attr, _table_name) }

    # Careful when possibly a user has both good and bad role like quarantined_seller
    scope :by_real_sellers, lambda {|user_id_attr = nil, _table_name = nil| 
      with_role_ids(Spree::Role.real_seller_roles.collect(&:id), user_id_attr, _table_name) }

    # Unliked by_real_sellers, this excludes quarantined_seller by using seller_rank
    scope :by_viable_sellers, lambda {|user_id_attr = nil, _table_name = nil| 
      joins(:user).where("seller_rank >= ?", Spree::User::BASE_PENDING_SELLER_RANK).without_role_ids(Spree::Role.unreal_user_role_ids, user_id_attr, _table_name ) }

    scope :by_unreal_users, lambda {|user_id_attr = nil, _table_name = nil| 
      with_role_ids(Spree::Role.unreal_user_role_ids, user_id_attr, _table_name) }
    scope :not_by_unreal_users, lambda {|user_id_attr = nil, _table_name = nil| 
      without_role_ids(Spree::Role.unreal_user_role_ids, user_id_attr, _table_name) }
    scope :by_phantom_sellers, lambda {|user_id_attr = nil, _table_name = nil| 
      with_role_ids( [Spree::Role.phantom_seller_role.id], user_id_attr, _table_name ) }
    scope :not_by_phantom_sellers, lambda {|user_id_attr = nil, _table_name = nil| 
      without_role_ids( [Spree::Role.phantom_seller_role.id], user_id_attr, _table_name ) }

    scope :by_this_user, -> (user_id) { where("#{self.table_name}.user_id IS NOT NULL AND #{self.table_name}.user_id = ?", user_id) }
    scope :by_other_users, -> (user_id) { where("#{self.table_name}.user_id IS NULL OR #{self.table_name}.user_id != ?", user_id) }
  end
end