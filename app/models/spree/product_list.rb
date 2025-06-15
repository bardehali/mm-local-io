module Spree
  class ProductList < ApplicationRecord
    self.table_name = 'product_lists'
    
    has_many :product_list_products, dependent: :destroy
    has_many :products, through: :product_list_products
  end
end