class Ioffer::UserCategory < ApplicationRecord
  validates_presence_of :user_id, :category_id

  belongs_to :category
  belongs_to :user
end