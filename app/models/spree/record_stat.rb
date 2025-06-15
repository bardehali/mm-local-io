##
# Record for holding temporary stats:
# For example: 
#   counts of products per retail site would be 
#     record_type='Spree::Product', record_column='retail_site_id'
#     and would produce entries like 
#       record_id=2, record_count=2000
#       record_id=1, record_count=5000
class Spree::RecordStat < ApplicationRecord
  self.table_name = 'spree_record_stats'

  include ::WithOtherRecord

  validates :record_type, presence: true

  def self.record_id_class
    String
  end

  ##
  # Makes group by counts for the record_type
  # @klass [Class or String of class name]
  # @attributes [Hash w/ symbolized keys] 
  #   This might be different than record_type converted fro @klass, for example,
  #   when counts of variants using option values wanted, so arguments would be 
  #   record_type=Spree::OptionValueVariant, record_column='option_value_id', { record_type: 'Spree::OptionValue', record_column:'id' }
  def self.save_group_counts_for(klass, record_column = 'id', attributes = {})
    klass ||= record_type.class == Class ? record_type : record_type.constantize
    attributes[:record_type] ||= klass.to_s
    attributes[:record_column] ||= record_column
    klass.group(record_column).count.each do|record_id, cnt|
      entry = self.find_or_initialize_by(attributes.merge(record_id: record_id) )
      entry.record_count = cnt
      entry.save
    end
  end
end