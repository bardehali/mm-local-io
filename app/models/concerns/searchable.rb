##
# Module to add Elasticsearch functions.
# But this does not include ::Elasticsearch::Model::Callbacks yet.  Call that if you 
# want auto updating to index upon record changes.
module Searchable
  extend ActiveSupport::Concern

  included do
    include ::Elasticsearch::Model

    ##
    # Prepare callbacks based call @method_name to determine to import into or delete from index.
    def self.index_document_when(method_name)
      self.after_commit on: [:create] do
        __elasticsearch__.index_document if self.send(method_name)
      end
    
      self.after_commit on: [:update] do
        if self.send(method_name)
          __elasticsearch__.index_document
        else
          begin
            __elasticsearch__.delete_document
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
          end
        end
      end
    
      self.after_commit on: [:destroy] do
        begin
          __elasticsearch__.delete_document
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
        end
      end
    end

    ##
    # This would be exact argument to plug into Elasticsearch::Model.search(xxxx)
    # @conditions [Hash of field(String or Array) =>
    #   expected values(String to be one exact or Array to be conditional OR) ]
    # Resulting generation of Elasticsearch query arguments could be like:
    # query:{
    #   bool:{
    #       must:[
    #           { simple_query_string:{ query:"blue | blue jeans", fields:['presentation'] } },
    #           { simple_query_string:{ query:"brand", fields:['option_type_presentation'] } }
    #       ]
    #   }
    # }
    def self.build_nested_query(conditions = {})
      must_conditions = []
      conditions.each_pair do|field, values|
        simple_query = { fields: field.is_a?(String) ? [field] : field,
          query: values.is_a?(Array) ? values.join(' | ') : values }
        must_conditions << { simple_query_string: simple_query }
      end
      { query:{ bool: {must: must_conditions } } }
    end

    def self.es
      self.__elasticsearch__
    end

    def self.rebuild_index!(run_import = true)
      begin
        es.delete_index!
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        puts '** Index NotFound'
      end
      es.create_index!
      self.import if run_import
    end

    def self.bulk_index(ids_or_records = [])
      return [] if ids_or_records.blank?
      records = ids_or_records.first.is_a?(Numeric) ? self.where(id: ids_or_records) : ids_or_records
      batch = []
      records.each do|record|
        batch << { index:{_id: record.id, data: record.as_indexed_json }} if record.indexable?
      end
      self.es.client.bulk(index: es.index_name, body: batch)
    end

    #######################
    # Instance methods

    alias_method :es, :__elasticsearch__

  end

  ##
  def exists_in_es?
    self.class.es.search(query:{ term:{_id: self.id } }).results.total > 0
  end
  alias_method :exists_in_elasticsearch?, :exists_in_es?
end