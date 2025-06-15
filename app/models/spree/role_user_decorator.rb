module Spree::RoleUserDecorator

  def self.prepended(base)
    base.extend ClassMethods
    base.after_create :update_seller_rank!
    base.after_destroy :update_seller_rank!
  end

  module ClassMethods
    def ransackable_attributes(*_args)
      %w[user_id role_id]
    end
  end

  def update_seller_rank!
    user.schedule_to_calculate_stats! if user
  end
end

Spree::RoleUser.prepend(Spree::RoleUserDecorator) if Spree::Role.included_modules.exclude?(Spree::RoleUserDecorator)