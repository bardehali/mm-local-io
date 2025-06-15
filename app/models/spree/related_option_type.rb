module Spree
  class RelatedOptionType < Spree::Base

    include WithOtherRecord

    belongs_to :option_type, class_name: 'Spree::OptionType'
    belongs_to :taxon, class_name: 'Spree::Taxon', foreign_key: :record_id

    default_scope -> { order(:position) }

    ##
    # Extends beyond just option_type association, for record_type like
    # category Spree::Taxon, find closest by level (low to high).
    # @record_id [Integer or String]
    # @return <list of Spree::OptionType#id>
    def self.closest_option_type_ids(record_type, record_id = nil)
      option_type_ids = []
      if record_type == 'Spree::Taxon'
        record_ids = convert_to_array_of_ids(record_id)

        # Could not use .where(.... record_id: category_taxon_ids) because diff category levels maybe diff
        record_type.constantize.where(id: record_ids).each do|record|
          if record.respond_to?(:is_category?) ? record.is_category? : record.permalink.try(:start_with?, 'categories')
            record_option_type_ids = nil
            record.categories_in_path.each do|category_taxon|
              break if record_option_type_ids && record_option_type_ids.size > 0
              record_option_type_ids = self.where(record_type: record_type, record_id: category_taxon.id).collect(&:option_type_id)
            end
            option_type_ids += record_option_type_ids if record_option_type_ids
          end
        end
      else
        scope = self.where(record_type: record_type)
        scope = scope.where(record_id: record_id) if record_id || record.present?
        option_type_ids = scope.collect(&:option_type_id)
      end
      option_type_ids.flatten.uniq
    end

    def self.closest_option_types(record_type, record_id = nil)
      ::Spree::OptionType.where(id: closest_option_type_ids(record_type, record_id) ).includes(:option_values).all
    end

    def self.closest_option_types_to(record)
      closest_option_types(record.class.to_s, record.id)
    end

  end
end