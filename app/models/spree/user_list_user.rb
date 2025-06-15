module Spree
  class UserListUser < ApplicationRecord
    self.table_name = 'user_list_users'

    validates_uniqueness_of :user_id, case_sensitive: true, scope: [:user_list_id, :user_id]

    belongs_to :user, -> { unscoped }
    belongs_to :user_list
  end
end