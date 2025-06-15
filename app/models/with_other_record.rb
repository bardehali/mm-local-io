##
# Models w/ columns record_type plus record_id
module WithOtherRecord
  extend ActiveSupport::Concern

  included do
    def self.record_id_class
      Integer
    end

    def self.record_class_attribute_name
      :record_type
    end

    ##
    # @return [Hash] the conditions for finding the related record of this model.
    def self.conditions_for_record(record)
      conds = { record_class_attribute_name => record.class.to_s }
      if record.id
        conds[:record_id] = record_id_class.is_a?(String) ? record.id.to_s : record.id
      end
      conds
    end

    def self.for_record(record)
      where(conditions_for_record(record) )
    end

    # @return [Array of Integer]
    def self.convert_to_array_of_ids(record_id = nil)
      record_ids = nil
      if record_id.is_a?(Integer)
        record_ids = [record_id]
      elsif record_id.is_a?(String)
        record_ids = record_id.split(',').collect(&:to_i)
      elsif record_id.is_a?(Array)
        record_ids = record_id.compact.collect(&:to_i)
      end
      record_ids
    end

    #############################
    # Instance methods

    def record
      record_class = record_type.constantize
      @record ||= record_class.respond_to?(:with_deleted) ?
        record_class.with_deleted.where(id: record_id).first : record_class.find_by(id: record_id)
    end
  end
end