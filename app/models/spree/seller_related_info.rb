##
# For 
module Spree::SellerRelatedInfo
  extend ::ActiveSupport::Concern

  ##
  # "Highest seller ranking from sellers who have logged in last 2 weeks, with lowest price as the tiebreak"
  def seller_based_sort_rank
    if user.nil? || user.quarantined? || user.test_or_fake_user_except_phantom?
      0
    elsif user.phantom_seller?
      ( user.seller_rank || user.calculate_seller_rank ) + (50000 - price.to_f)
    elsif !user.active?
      0
    else
      # avoid high price
      (price.to_f == 0.0) ? 0 : seller_rank.to_i + (50000 - price)
    end
  end

  def has_acceptable_adopter?
    seller_based_sort_rank >= Spree::User::MINIMUM_SELLER_BASED_SORT_RANK_FOR_ADOPTION
  end

  def has_good_standing_seller?
    seller_based_sort_rank >= Spree::User::MINIMUM_GOOD_STANDING_SELLER_BASED_SORT_RANK
  end
end