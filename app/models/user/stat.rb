##
# More flexible data recording than Spree::RecordStat mainly for user
# because this does not need class defined in record_type.
module User
  class Stat < ApplicationRecord
    self.table_name = 'user_stats'

    validates_presence_of :user_id, :name

    belongs_to :user, class_name:'Spree::User'

    whitelisted_ransackable_attributes = ['user_id', 'name', 'value', 'updated_at']

    ##
    # Yield to block if stat not found, and expect either Stat or String
    def self.fetch(user_id, name, &block)
      stat = User::Stat.where(user_id: user_id, name: name).first
      if stat.nil?
        stat_value_or_record = yield if block_given?
        stat_value_or_record.is_a?(User::Stat) ? stat_value_or_record : 
          new(user_id: user_id, name: name, value: stat_value_or_record.to_s) 
      else
        stat
      end
    end

    def self.fetch_or_set(user_id, name, &block)
      stat = fetch(user_id, name) do
        stat_value_or_object = yield if block_given?
      end
      stat.save if stat
      stat
    end
  end # class
end