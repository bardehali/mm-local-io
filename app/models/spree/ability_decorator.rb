module Spree::AbilityDecorator

  def self.prepended(base)
    base.attr_accessor :user
    base.extend(ClassMethods)
  end

  module ClassMethods
    def initialize(user)
      super(user)
      self.user = user
    end
  end

  def public_action?(action)
    %w(read index).include?(action.to_s)
  end

  # From /spree-master/guides/src/content/developer/tutorials/security.md
  # unknown connections because not sure manageable by user
  # Spree::CustomerReturn, Spree::StockLocation, Spree::Promotion
  #can :read, Artwork do |artwork|
  #  artwork.order && artwork.order.user == user
  #end
  #can :update, Artwork do |artwork|
  #  artwork.order && artwork.order.user == user
  #end

  @@manage_actions = [:read, :show, :index, :create, :update, :destroy]
  @@readonly_actions = [:read, :show, :index]
  @@modify_actions = [:update, :destroy]

  def initialize(user)
    super(user)
    self.user = user
    
    # with user_id, either missing or different in original Spree::Ability
    [
      Spree::OptionValue,
      Spree::Product,
      Spree::Variant,
      Spree::CreditCard,
      Spree::Store
    ].each do|klass|
      allow_to_manage(user, klass) if user
      can [:create], klass
    end

    allow_to_manage(user, User::Message) if user
    cannot [:create], User::Message

    can [:toggle_selling_taxon, :upload_images], Spree::Product
    if user&.buyer?
      cannot [:adopt], Spree::Product
      cannot [:fill_your_shop], Spree::Store
    end

    can [:edit, :update], Spree::User do|record| 
      record.id == user.id
    end

    # Orders
    
    can [:index], Spree::Order if user
    can [:sales], Spree::Order if user&.seller? && !user&.quarantined_user?
    can [:edit, :show], Spree::Order do|record|
      record.user_id == user&.id
    end
    can [:read, :show, :cart, :cancel], Spree::Order do|record|
      (record.user_id.nil? && user.nil?) || record.user_id == user.try(:id) || record.seller_user_id == user.try(:id)
    end

    # Only seller
    if user&.seller?
      can [:list_same_item, :list_variants], Spree::Product
    end

    # Only seller of the order
    can [:edit, :update, :approve, :resume, :open_adjustments, :close_adjustments], Spree::Order do|record|
      record.seller_user_id == user.try(:id)
    end
    can [:index], Spree::Payment
    if user.try(:approved_seller?)
      can [:manage, :seller_manage], Spree::Order do|record|
        record.seller_user_id == user.try(:id)
      end
    end
    cannot [:destroy], Spree::Order
    cannot :create, Spree::Order if user&.seller?

    # depends on product.user_id
    [
      Spree::ProductOptionType,
      Spree::ProductProperty,
      Spree::Classification,
      Spree::Variant,
      Spree::ProductPromotionRule,
      Spree::StockItem,
    ].each do|klass|
      allow_to_manage_association_related(user, klass, :product) if user
      can [:create], klass
    end
    
    # depends on viewable.user_id
    can [:update, :delete, :delete_image], Spree::Image do|image|
      image.viewable.respond_to?(:user_id) && user&.id == image&.viewable&.user_id
    end

    # depends on store.user_id
    [
      Spree::StorePaymentMethod
    ].each do|klass|
      allow_to_manage_association_related(user, klass, :store) if user
      can [:create], klass
    end
    can [:toggle], Spree::StorePaymentMethod

    # for buyer and seller of order
    [
      Spree::LineItem,
      Spree::Payment
    ].each do|klass|
      can @@readonly_actions, klass do|o| 
        (o.order.user_id == user.id || o.order.seller_user_id == user.id )
      end
    end if user
    can [:create], Spree::LineItem
    can [:show, :capture], Spree::Payment

    # for seller of the order
    [
      Spree::Adjustment
    ].each do|klass|
      can :manage, klass, order: { seller_user_id: user.id }
    end if user
    can :create, Spree::Payment do|payment|
      payment.order&.seller_user_id == user.id
    end if user

    # viewable and its product.user_id
    [
      Spree::Asset
    ].each do|klass|
      can @@manage_actions, klass, viewable: { user_id: user.id } if user
      can [:create], klass
    end

    # view only
    [
      Spree::StockLocation
    ].each do|klass|
      can [:read, :show, :index], klass
    end

    # admin level operations
    can [:sign_in_as], Spree::User if user.try(:admin?)

  end

  protected

  # Check against record of specified class checking its user_id
  def allow_to_manage(user, klass)
    can :manage, klass do |record|
      if record.is_a?(::Spree::Product)
        (record.user_id == user.id || user&.admin? )
        # record.variants_including_master.select('user_id').collect(&:user_id).include?(user.id) )
      elsif record.respond_to?(:user_id)
        record.user_id && record.user_id == user.id
      elsif record.respond_to?(:recipient_user_id)
        record.recipient_user_id && record.recipient_user_id == user.id
      else
        false
      end
    end
  end

  ##
  # Populate can :update and :destroy calls to allow user 
  # to modify a record of specified class through its association that 
  # has user_id reference.
  def allow_to_manage_association_related(user, klass, association_name)
    can :manage, klass, association_name => { user_id: user.try(:id) } if user
  end
end

# ::Spree::Ability.register_ability(AbilityDecorator)

::Spree::Ability.prepend ::Spree::AbilityDecorator if ::Spree::Ability.included_modules.exclude?(::Spree::AbilityDecorator)
