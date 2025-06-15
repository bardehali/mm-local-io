module Spree
  class UserList < ApplicationRecord
    self.table_name = 'user_lists'
    
    has_many :user_list_users, dependent: :destroy
    has_many :users, through: :user_list_users
  end
end