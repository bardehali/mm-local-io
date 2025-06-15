module Spree::RoleDecorator

  def self.prepended(base)
    base.extend ClassMethods

    # somehow calling this way would break: admin_role.users
    base.has_many :users, through: :role_users, class_name: 'Spree::User'

    base.scope :bad_roles, -> { where(name: %w(quarantined_user) ) }
  end

  module ClassMethods
    def non_admin_roles
      Rails.cache.fetch('users.roles.non_admins', expires_in: 1.day) do
        Spree::Role.where('name NOT IN (?)', %w(admin supplier_admin)).all.to_a
      end
    end

    def non_buyer_roles
      Rails.cache.fetch('users.roles.non_buyers', expires_in: 1.day) do
        Spree::Role.all.to_a # currently no role means buyer
        # where(name: %w(admin approved_seller pending_seller test_user curated_user fake_user)).all.to_a
      end
    end

    ##
    # @return [Array of Spree::Role]
    def seller_roles
      Rails.cache.fetch('users.roles.sellers', expires_in: 1.day) do
        Spree::Role.where(name: %w(approved_seller pending_seller hp_seller phantom_seller)).all.to_a
      end
    end

    def real_seller_roles
      Rails.cache.fetch('users.roles.real_sellers', expires_in: 1.day) do
        Spree::Role.where(name: %w(approved_seller pending_seller hp_seller)).all.to_a
      end
    end

    # Those users that are posting real content, even test users
    def active_user_role_ids
      seller_roles.collect(&:id) + [test_user_role&.id]
    end

    # Not admin, not test nor fake
    def unreal_user_roles
      Rails.cache.fetch('users.roles.unreal_users', expires_in: 1.day) do
        Spree::Role.where(name: %w(admin test_user fake_user curated_user phantom_seller)).all.to_a
      end
    end

    alias_method :non_real_user_roles, :unreal_user_roles

    # Not admin, not test nor fake
    def unreal_user_roles_except_phantom
      Rails.cache.fetch('users.roles.unreal_user_roles_except_phantom', expires_in: 1.day) do
        Spree::Role.where(name: %w(admin test_user fake_user curated_user)).all.to_a
      end
    end

    def unreal_user_role_ids
      unreal_user_roles.collect(&:id)
    end

    def admin_role
      fetch_cached_role('admin')
    end

    def test_user_role
      fetch_cached_role('test_user')
    end

    def fake_user_role
      fetch_cached_role('fake_user')
    end

    def curated_user_role
      fetch_cached_role('curated_user')
    end

    def phantom_seller_role
      fetch_cached_role('phantom_seller')
    end

    def fetch_cached_role(role_name)
      Rails.cache.fetch("users.roles.#{role_name}", expires_in: Rails.env.production? ? 1.day : 1.minute) do
        Spree::Role.find_or_create_by(name: role_name)
      end
    end
  end

  ##############################
  # Instance methods

  def display_name
    name
  end

  def short_name
    s = name.gsub(/(_seller|_user)\Z/i, '')
    s == 'hp' ? 'handpicked' : s
  end
end

Spree::Role.prepend(Spree::RoleDecorator) if Spree::Role.included_modules.exclude?(Spree::RoleDecorator)