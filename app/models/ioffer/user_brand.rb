class Ioffer::UserBrand < ApplicationRecord
  belongs_to :brand
  belongs_to :user
end