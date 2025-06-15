require_dependency 'delayed/backend/active_record'

module Delayed
  module Backend
    module ActiveRecord
      module JobDecorator
        def self.prepended(base)
          base.before_create :set_record_class_and_id
          base.after_create :cleanup_duplicates!
          base.alias_attribute :record_type, :record_class
          base.include WithOtherRecord
        end

        module ClassMethods
          def record_class_attribute_name
            :record_class
          end
        end

        # @return <Ruby object or nil>
        def handler_object
          p = parse_handler
          if p.is_a?(Delayed::PerformableMethod)
            p.object
          else
            nil
          end
        end

        # @return <Symbol or nil> method name of handler's object
        def performable_method_name
          p = parse_handler
          if p.is_a?(Delayed::PerformableMethod)
            p.method_name.to_s
          else
            nil
          end
        end
    
        protected

        def parse_handler
          handler ? YAML::load(handler) : nil
        rescue Exception => parse_e
          Spree::User.logger.warn("** Problem parsing Delayed::Job(#{id}) handler: #{hander}")
          nil
        end
    
        def set_record_class_and_id
          if payload_object && payload_object.respond_to?(:object) && (record = payload_object&.object)
            self.record_class = record.class.to_s
            self.record_id = record.id
          end
        end

        def cleanup_duplicates!
          method_name = self.performable_method_name.to_s
          if record_class.present? && (method_name.blank? || method_name.match(/(increase|increment|decrease)/i).nil? )
            to_delete_ids = []
            ::Delayed::Job.where(record_class: record_class, record_id: record_id).
              where('id != ?', id).each do|other_dj|
                to_delete_ids << other_dj.id if other_dj.performable_method_name.to_s == method_name
            end
            ::Delayed::Job.where(id: to_delete_ids).delete_all if to_delete_ids.size > 0
          end
        end
      end
    end
  end
end

Delayed::Backend::ActiveRecord::Job.prepend(Delayed::Backend::ActiveRecord::JobDecorator) if Delayed::Backend::ActiveRecord::Job.included_modules.exclude?(Delayed::Backend::ActiveRecord::JobDecorator)