class Ioffer::Category < ApplicationRecord
  validates_presence_of :name

  has_many :category_to_taxons
  has_many :taxons, through: :category_to_taxons

  TO_SHOPPN_CATEGORIES_MAPPING = {
    "Women's Fashion" => ["Women's Clothing"], 
    "Men's Fashion" => ["Men's Clothing"], 
    "Sneakers" => ["Shoes & Sneakers > Women's Shoes > Sneakers", "Shoes & Sneakers > Men's Shoes > Sneakers"], 
    "Handbags" => ["Bags & Purses > Women's Luggage & Bags > Handbags"], 
    "Jewelry" => ["Jewelry & Watches > Women's Jewelry > Watches", "Jewelry & Watches > Men's Jewelry > Watches"], 
    "Watches" => ["Jewelry & Watches > Women's Jewelry", "Jewelry & Watches > Men's Jewelry"], 
    "Sunglasses" => ["Men's Clothing > Accessories > Sunglasses", "Women's Clothing > Accessories > Eyewear & Accessories"], 
    "Makeup" => ["Beauty & Health, Hair > Makeup"], 
    "Women's Shoes" => ["Shoes & Sneakers > Women's Shoes"], 
    "Accessories" => ["Women's Clothing > Accessories", "Men's Clothing > Accessories", "Jewelry & Watches"]
  }
end