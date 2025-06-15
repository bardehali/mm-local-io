module Spree
  class ItemReviewsController < Spree::StoreController
    before_action :set_item_review, only: %i[show purchases]

    def show
      @title = "#{@item_review.name.to_s.split(' ').first}'s Purchases"
      @purchased_items = Spree::Product.where(id: @item_review.purchased_item_ids)
    end

    def purchases
      @purchased_items = Spree::Variant.where(id: @item_review.purchased_item_ids)
      render :purchases
    end

    private

    def set_item_review
      @item_review = Spree::ItemReview.find_by!(code: params[:code])
    end
  end
end
