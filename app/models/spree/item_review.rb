module Spree
  class ItemReview < Spree::Base
    belongs_to :variant_adoption, class_name: 'Spree::VariantAdoption'

    validates :name, :reviewed_at, :rating, :body, presence: true
    validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
    validates :country_code, length: { is: 2 }, allow_nil: true
    validates :number, :rank, :purchase_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :code, presence: true, uniqueness: true

    scope :recent, -> { order(reviewed_at: :desc) }
    scope :highly_rated, -> { where('rating >= ?', 4).order(rating: :desc) }

    # Ensure JSON is stored as an array
    serialize :purchased_items, Array

    before_validation :generate_unique_code, on: :create

    private

    def generate_unique_code
      return unless self.code.blank? # Only generate if not already set

      loop do
        self.code = "PI#{SecureRandom.alphanumeric(10)}".upcase
        Rails.logger.info "Generated Code: #{self.code}"
        break unless self.class.exists?(code: code) # Ensure uniqueness
      end
    end
  end
end
