module Spree
  class VariantAdoption < Spree::Base

    acts_as_paranoid

    include ::Spree::UserRelatedScopes
    include ::Spree::DefaultPrice
    include ::Spree::SellerRelatedInfo

    self.table_name = 'spree_variant_adoptions'

    belongs_to :variant, -> { with_deleted }, class_name:'Spree::Variant', inverse_of: :variant_adoptions

    belongs_to :user, class_name:'Spree::User'

    has_many :prices, class_name:'Spree::AdoptionPrice', inverse_of: :variant_adoption, dependent: :destroy
    has_many :item_reviews, class_name: 'Spree::ItemReview'

    scope :not_deleted, -> { where("#{Spree::VariantAdoption.table_name}.deleted_at is NULL") }
    scope :no_line_item, -> {
      joins("LEFT JOIN #{Spree::LineItem.table_name} ON #{Spree::VariantAdoption.table_name}.id=#{Spree::LineItem.table_name}.variant_adoption_id").
      where("#{Spree::LineItem.table_name}.variant_id=#{Spree::VariantAdoption.table_name}.variant_id AND #{Spree::LineItem.table_name}.variant_adoption_id IS NULL") }

    delegate :product, :tax_category, :inventory_units, :line_items, :stock_items,
      :orders, :stock_locations, :stock_movements, :option_value_variants,
      :option_values, :images, :sku, :purchasable?, :backorderable?,
      :create_variant_adoption_for,
      to: :variant
    delegate :seller_rank, :current_sign_in_at, :last_active_at, to: :user

    whitelisted_ransackable_attributes = %w[user_id]

    ##
    # Overriding DefaultPrice
    include Spree::DefaultPrice

    has_one :default_price,
              -> { where currency: Spree::Config[:currency] },
              class_name: 'Spree::AdoptionPrice'

    belongs_to :line_item

    # Trigger calls

    before_create :set_other_attributes


    SLUG_REGEXP = /(\S+\-)?([\w]+)\Z/i

    ##
    # In some cases, even though there's dependent: :destroy options inside Variant, variants
    # still not deleted, yet adoptions should since no access to sell.
    def self.soft_delete_with_deleted_users
      joins("join #{Spree::User.table_name} on user_id=#{Spree::User.table_name}.id").where("spree_users.deleted_at is not null").update_all(deleted_at: Time.now)
    end

    #############################
    # Accessors

    def price_in(currency)
      prices.detect { |price| price.currency == currency } || prices.build(currency: currency)
    end

    def amount_in(currency)
      price_in(currency).try(:amount)
    end

    ##
    # Expected this used for product.display_variant_adoption_code
    # * pick other phantom seller and create VariantAdoption
    # * update the item to point display_variant_adoption_code to new VariantAdoption
    # * update product in search index
    def takedown!(record_review_status_code = nil)
      va = self.variant.create_phantom_variation_adoption!

      Spree::LineItem.joins(:order).where("state='cart'").
        where(variant_id: variant_id, variant_adoption_id: id).all.each(&:destroy)

      # in case ES update_document doesn't reload
      self.product.rep_variant_id = va.variant_id
      self.product.display_variant_adoption_code = va.code
      self.product.update_columns(rep_variant_id: va.variant_id, display_variant_adoption_code: va.code, updated_at: Time.now)
      self.product.es.update_document


      record_review_status_code ||= Spree::RecordReview.status_code_for('Listing Violation')
      Spree::RecordReview.create(record_type: self.class.to_s, record_id: self.id,
        status_code: record_review_status_code)

      self.destroy
      va
    end

    def set_other_attributes
      self.code = SecureRandom.urlsafe_base64(16).gsub('-','_') if code.blank?
    end
  end
end
