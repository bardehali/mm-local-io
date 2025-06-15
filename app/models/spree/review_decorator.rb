##
# Buyer review of the product.
module Spree::ReviewDecorator
  REQUIRES_PURCHASE_TO_REVIEW = true unless defined?(REQUIRES_PURCHASE_TO_REVIEW)

  def self.prepended(base)
    base.include Spree::UserRelatedScopes

    base.extend ClassMethods
    base.validate :check_permission
    
    base.unvalidates :review

    base.after_save :update_product!

    base.attr_accessor :skip_check_permission

    base.belongs_to :product, -> { with_deleted }, class_name:'Spree::Product'
  end

  module ClassMethods
    ##
    # To skip possible default scope conflict, such as "spree_users.deleted_at IS NULL",
    # this provides better control on accurate ActiveRecord.joins()
    def user_list_user_users_joins_string
      "INNER JOIN `#{Spree::User.table_name}` ON `#{Spree::User.table_name}`.`id` = `#{Spree::Review.table_name}`.`user_id` INNER JOIN `#{Spree::UserListUser.table_name}` ON `#{Spree::UserListUser.table_name}`.`user_id` = `#{Spree::User.table_name}`.`id`"
    end

    def user_allowed_to_review?(user, product_id)
      !REQUIRES_PURCHASE_TO_REVIEW ||
        ( !Ioffer::ProductReviewGenerator::REQUIRES_ORDER_CREATED && user.test_or_fake_user? ) ||
        user.has_ordered_product?(product_id)
    end
  end

  #####################################
  # Overrides

  def recalculate_rating
    return if self.skip_check_permission
    super
  end



  #####################################

  ##
  # Within last 4 days and 6 hours ago.
  def fake_recent_created_at
    @fake_recent_created_at ||= 6.hours.ago - rand(90).hours + created_at.min + created_at.sec
  end

  def check_permission
    return if self.skip_check_permission
    user = self.user || Spree::User.find_by(id: user_id)
    product_id = self.product&.id || product_id
    product_user_id = self.product&.user_id
    if user && user&.id != product_user_id && Spree::Review.user_allowed_to_review?(user, product_id)
      if new_record? && Spree::Review.where(user_id: user.id, product_id: product_id).count > 0
        self.errors.add(:base, I18n.t('errors.review.already_reviewed_this') )
      end
    else
      self.errors.add(:base, I18n.t('errors.review.not_allowed_to_review_this') )
    end
  end

  def update_product!
    cnt = Spree::Reviews::Config[:include_unapproved_reviews] == false ?
      product.reviews.approved.count : product.reviews.count
    self.product.update_columns(reviews_count: cnt )
  end


end

Spree::Review.prepend(Spree::ReviewDecorator) if Spree::Review.included_modules.exclude?(Spree::ReviewDecorator)
