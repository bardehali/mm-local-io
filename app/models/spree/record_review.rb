module Spree
  class RecordReview < Spree::Base
    include WithOtherRecord

    scope :removeable, -> { where('status_code >= ?', NAME_TO_STATUS_CODE_MAPPING['Prohibited'] ) }

    MAX_ACCEPTABLE_STATUS_CODE = 99
    STATUS_CODE_TO_NAME_MAPPING = {
      0 => 'Default', 50 => 'Good Image', 55 => 'Ok Image',
      100 => 'Bad Main Image', 200 => 'Wrong Category', 300 => 'Catalog Listing', 400 => 'Keyword Spam',
      1000 => 'Prohibited', 1100 => 'Contact Info', 1200 => 'Listing Violation', 1300 => 'Custom Watermarks'
    }
    NAME_TO_STATUS_CODE_MAPPING = {}
    STATUS_CODE_TO_NAME_MAPPING.each{|k, v| NAME_TO_STATUS_CODE_MAPPING[v] = k }
    STATUS_CODE_TO_CURATION_SCORE_MAPPING = {
      50 => 40, 55 => ::Spree::Product::DEFAULT_IQS,
      100 => 1, 200 => 2, 300 => 3, 400 => 4, 1000 => 0, 1100 => 0, 1200 => 0, 1300 => 0
    }

    validates_presence_of :record_type, :record_id, :status_code

    before_save :set_curation_scores
    after_save :apply_to_record!

    def target_curation_score
      new_record? && new_curation_score ? new_curation_score : STATUS_CODE_TO_CURATION_SCORE_MAPPING[status_code]
    end

    def status_name
      STATUS_CODE_TO_NAME_MAPPING[status_code]
    end

    ## Whether this status_code would force item to be removed/destroy (soft).
    def record_removeable?
      status_code.to_i >= NAME_TO_STATUS_CODE_MAPPING['Prohibited']
    end

    def self.default_per_page
      100
    end

    def self.status_code_for(status_name)
      NAME_TO_STATUS_CODE_MAPPING[status_name]
    end

    def self.iqs_for(status_name)
      curation_score_for(status_name)
    end

    protected

    def self.curation_score_for(status_name)
      STATUS_CODE_TO_CURATION_SCORE_MAPPING[ status_code_for(status_name) ]
    end

    def set_curation_scores
      if record.is_a?(::Spree::Product)
        self.previous_curation_score = record.curation_score if new_record?
        self.iqs = self.new_curation_score = target_curation_score
      end
    end

    ##
    # This would toggle the status_code if current is same
    def apply_to_record!
      if record.respond_to?(:curation_score)
        auto_set_iqs = record.respond_to?(:build_auto_set_attributes) ? record.build_auto_set_attributes.try(:[], :iqs) : 0

        default_score = record.class.constants.include?('INITIAL_CURATION_SCORE'.to_sym) ? record.class::INITIAL_CURATION_SCORE : nil
        _new_curation_score ||= new_curation_score
        _new_curation_score ||= default_score
        attr = { curation_score: _new_curation_score, status_code: status_code, last_review_at: Time.now }
        logger.debug "| applying to #{record}\n  w/ #{attr}, removable? #{record_removeable?}"

        # Supposedly iqs replacing curation_score, but curation is kept for now, and same
        record_old_iqs = record.respond_to?(:iqs) ? (record.iqs || default_score) : default_score
        attr[:iqs] = _new_curation_score if record.respond_to?(:iqs)

        logger.debug "  record old iqs #{record_old_iqs} vs #{_new_curation_score}"
        if record_old_iqs != auto_set_iqs && _new_curation_score == default_score # resets score back
          record.recalculate_status! if record.respond_to?(:recalculate_status!)
        elsif record.last_review_at.nil? || status_code || new_curation_score || iqs
          update_status = record.update(attr)
        end

        begin
          if record_removeable?
            record.es.delete_document if record.deleted_at.nil?
          elsif record.respond_to?(:deleted?) && record.deleted?
            record.update(deleted_at: nil)
            record.es.update_document
          end
        rescue Elasticsearch::Transport::Transport::Error => es_e
          logger.debug "** cannot update product #{record.id} in ES: #{es_e}"
        end
      end
    end
  end
end