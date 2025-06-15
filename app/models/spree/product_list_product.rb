module Spree
  class ProductListProduct < ApplicationRecord
    self.table_name = 'product_list_products'

    validates_uniqueness_of :product_id, scope: [:product_list_id, :product_id]

    belongs_to :product_list, -> { unscoped }
    belongs_to :product

    default_scope { order(:id) }
  end
end