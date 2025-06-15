class SearchKeyword < ApplicationRecord

  include ::Searchable
  include ::Elasticsearch::Model
  include ::Elasticsearch::Model::Callbacks

  before_save :normalize_attributes
  before_create :set_result_count
  
  index_name "search-keywords-#{Rails.env == 'staging' ? 'production' : Rails.env}" 

  def self.settings_attributes
    {
      index: {
        analysis: {
          analyzer: {
            autocomplete: {
              type: :custom,
              tokenizer: :my_tokenizer,
              filter: %i[lowercase]
            }
          },
          tokenizer: {
            my_tokenizer:{
              type: :edge_ngram,
              min_gram: 1,
              max_gram: 25
            }
          }
        }
      }
    }
  end

  settings settings_attributes do
    mappings dynamic: false do
      indexes :keywords, type: :text
      indexes :keywords_ngram, type: :text, analyzer: :autocomplete
      indexes :search_count, type: :integer
    end
  end

  ##
  # Generates the default search definition w/ :query, :sort, :hightlight, :size
  # @return [Elasticsearch::Model::Response::Response]
  def self.make_search(query, other_search_definition = {})
    set_filters = lambda do |context_type, filter|
      @search_definition[:query][:bool][context_type] |= [filter]
    end

    @search_definition = {
      size: 10,
      query: {
        bool: {
          must: [],
          should: [],
          filter: []
        }
      },
      sort: [{'search_count':{ order:'desc' }}, {'_score':{ order:'desc' }} ],
      highlight:{ pre_tags:['<strong>'], post_tags:['</strong>'], fields:{ keywords_ngram:{} } }
    }.merge(other_search_definition)

    if query.blank?
      set_filters.call(:must, match_all: {})
    else
      set_filters.call(
        :must,
        term:{ keywords_ngram: query }
      )
    end

    es.search(@search_definition)
  end


  INVALID_CHARS_REGEXP = /([^\s\w\-\+\.\/*]+)/i

  def self.clean_chars(kw)
    return nil if kw.nil?
    kw.gsub(INVALID_CHARS_REGEXP, ' ').strip_naked[0, 100]
  end

  def self.populate_from_search_logs!(minimum_search_count = nil, minimum_result_count = 1)
    SearchLog.group(:keywords).count.each_pair do|kw, cnt|
      cleaned_kw = clean_chars(kw)
      puts "| #{cleaned_kw} | #{cnt}"
      next if cleaned_kw.blank? || minimum_search_count && cnt < minimum_search_count

      result_count = fetch_result_count(cleaned_kw)
      next if minimum_result_count && result_count < minimum_result_count

      search_kw = SearchKeyword.find_or_initialize_by(keywords: cleaned_kw)
      search_kw.search_count = cnt
      search_kw.result_count = result_count if search_kw.respond_to?(:result_count=)
      search_kw.save
    end
  end

  def self.fetch_result_count(kw)
    Spree::Product.search(kw).results.total
  end


  ##########################
  # Instance methods

  def as_indexed_json(options = {})
    { keywords: keywords, keywords_ngram: keywords, search_count: search_count, 
      result_count: ( self.respond_to?(:result_count) ? result_count : 0 ) }
  end

  def set_result_count
    self.result_count = SearchKeyword.fetch_result_count(keywords) if self.respond_to?(:result_count=)
  end

  protected


  def normalize_attributes
    self.keywords = self.class.clean_chars(keywords) if keywords
  end
end