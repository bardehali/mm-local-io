##
# Implementation of settings and methods to use ElasticSearch
# product_searchable, products_searchable, searchable_option_values_map
module Spree::ProductSearchable

  extend ActiveSupport::Concern

  included do
    #index_name "shoppn-products-#{Rails.env == 'staging' ? 'v4-weighted' : (Rails.env == 'production' ? 'v2-production' : Rails.env ) }"
    #index_name "shoppn-products-#{Rails.env == 'staging' ? 'v3-production' : (Rails.env == 'production' ? 'v3-production' : Rails.env ) }"
    index_name "mm-local-io-products-#{Rails.env}"

    index_document_when :indexable?

    def self.settings_attributes
      {
        index: {
          analysis: {
            analyzer: {
              ngram_analyzer: {
                tokenizer: :ngram_tokenizer,
                filter: %w(lowercase)
              },
              autocomplete: {
                type: :custom,
                tokenizer: :standard,
                filter: %i[lowercase autocomplete_filter]
              },
              gender_synonyms_analyzer: {
                tokenizer: "standard",
                filter: ["lowercase", "gender_synonym_filter"]
              },
              brand_synonyms_analyzer: {
                tokenizer: "standard",
                filter: ["lowercase", "brand_synonym_filter"]
              },
              taxon_synonyms_analyzer: {
                tokenizer: "standard",
                filter: ["lowercase", "taxon_synonym_filter", "english_stemmer"]
              }
            },
            filter: {
              autocomplete_filter: {
                type: :edge_ngram,
                min_gram: 1,
                max_gram: 25
              },
              gender_synonym_filter: {
                type: "synonym",
                synonyms: [
                "male, man, men, guy, male's, man's, men's, guys, guy's, males, mans, mens, guys",
                "female, woman, women, lady, female's, woman's, women's, ladies, females, womens, womans, lady's"
                ]
              },
              brand_synonym_filter: {
                type: "synonym",
                synonyms: [
                "Louis Vuitton, LV",
                "Chanel, Coco Chanel, CC",
                "Yves Saint Laurent, YSL, Saint Laurent, Laurent",
                "Gucci, GG",
                "Off White, Off-White"
                ]
              },
              taxon_synonym_filter: {
                type: "synonym",
                synonyms: ["hat, cap",
                  "sunglasses, shades",
                  "tshirt, t-shirt, tee",
                  "jacket, coat"
                ]
              },
              english_stemmer: {
                "type": "stemmer",
                "language": "english"
              }
            },
            tokenizer: {
              ngram_tokenizer: {
                type: 'ngram',
                min_gram: 1,
                max_gram: 2
              }
            }
          }
        }
      }
    end

    settings settings_attributes do
      mappings dynamic: true do
        indexes :predicate_text, type: :text, analyzer: :standard
        indexes :other_text, type: :text, analyzer: :english
        indexes :name, type: :text, analyzer: :english
        indexes :description, type: :text, analyzer: :english
        indexes :brand, type: :text, analyzer: :brand_synonyms_analyzer
        indexes :brand_1, type: :text, analyzer: :brand_synonyms_analyzer
        indexes :brand_2, type: :text, analyzer: :brand_synonyms_analyzer
        indexes :brand_3, type: :text, analyzer: :brand_synonyms_analyzer
        indexes :brand_value, type: :integer
        indexes :brand_1_value, type: :integer
        indexes :brand_2_value, type: :integer
        indexes :brand_3_value, type: :integer
        indexes :lone_title, type: :text, analyzer: :taxon_synonyms_analyzer
        indexes :genders, type: :text, analyzer: :gender_synonyms_analyzer

        indexes :user_id, type: :integer
        indexes :adopter_user_ids, type: :integer
        indexes :retail_site_id, type: :integer
        indexes :taxon_ids, type: :integer
        indexes :taxons, type: :text, analyzer: :taxon_synonyms_analyzer
        indexes :promotionable, type: :integer
        indexes :supply_priority, type: :integer

        indexes :option_type_ids, type: :integer
        indexes :option_value_ids, type: :integer
        indexes :option_values, type: :text, analyzer: :standard
        indexes :meta_title, type: :text, analyzer: :standard
        indexes :meta_description, type: :text, analyzer: :standard
        indexes :meta_keywords, type: :text, analyzer: :standard

        indexes :view_count, type: :integer
        indexes :iqs, type: :integer
        indexes :curation_score, type: :integer
        indexes :taxon_weight, type: :float
        indexes :transaction_count, type: :integer
        indexes :recent_transaction_count, type: :integer
        indexes :recent_view_count, type: :integer
        indexes :last_transaction_time, type: :date
        indexes :viable_adopter_count, type: :integer
        indexes :last_adopted_at, type: :date
        indexes :price, type: :float
        indexes :best_price, type: :float
        indexes :created_at, type: :date
      end
    end

    ##########################################
    # Search methods


    DEFAULT_SORT_BY_STATS = [ { gms: 'desc' }, { transaction_count: 'desc' }, { view_count: 'desc'} ]
    DEFAULT_NO_TEXT_SORT = [ { iqs:'desc'}, { curation_score:'desc'}, { recent_transaction_count: 'desc' }, { recent_view_count:'desc'}, {'_id':'desc' } ]
    DEFAULT_SEARCH_SORT =  [ {'_score': {order:'desc'} }, {'recent_transaction_count':{ order:'desc'} }, {'recent_view_count':{ order:'desc'}}, {'_id':{ order:'desc'}} ]
    DEFAULT_SCRIPT_SCORE_SOURCE = "_score + 0.1*doc['recent_transaction_count'].value + 0.4*doc['curation_score'].value + 0.5*doc['iqs'].value"
    FILTER_ATTRIBUTES = [:user_id, :taxon_ids, :option_type_ids, :option_value_ids, :price,
      :sort, :sort_by, :script_score_source, :text_fields, :filter]

      ### 'new_search, 'dis_max', 'multimatch' else it does a full document search.
    DEFAULT_SEARCH_TYPE = 'new_search'

    ##
    # @query [String] keyword/text query.  If prefixed w/ 'dis_max:' or 'multi_match:', would
    #   build keyword query in that query type's syntax.
    def self.search(query, filters = {}, highlight = [], search_override = nil, &block)


    if search_override.present?
      begin
        # Attempt to parse the JSON string from the search_override parameter
        override_search_definition = JSON.parse(search_override)

        # Use the parsed JSON as the search definition directly
        @search_definition = override_search_definition
      rescue JSON::ParserError => e
        # Handle error, perhaps set @search_definition to a default value or return an error response
        @search_definition = make_basic_search_definition.merge(size: Spree::Product.default_per_page)
        # Consider how to handle this error, maybe return a default search or an error message
        return es.search(@search_definition)
      end
        # Execute the search with the overridden search definition and return immediately
        return es.search(@search_definition)
      end

      # a lambda function adds conditions to a search definition
      set_filters = lambda do |context_type, filter|
        outer_query_h = @search_definition[:query][:function_score] ? @search_definition[:query][:function_score][:query] : @search_definition[:query]
        outer_query_h[:bool] ||= {}
        # allow combined boolean
        outer_query_h[:bool][context_type] ||= []
        outer_query_h[:bool][context_type] << filter
      end

      #logger.debug "|> given filters #{filters}"

      @search_definition = make_basic_search_definition.merge(size: Spree::Product.default_per_page)

      #logger.debug "|> search definition made #{@search_definition}"
      sort_order = make_sort_order( filters.delete(:sort) || filters.delete(:sort_by), query )
      #logger.debug "|> sort made #{sort_order}"
      @search_definition[:sort] = sort_order if sort_order

      script_score_source = filters.delete(:script_score_source)
      script_score_source = DEFAULT_SCRIPT_SCORE_SOURCE if script_score_source.blank?
      text_fields = filters.delete(:text_fields)
      text_fields = text_fields.is_a?(String) ? text_fields.split(' ') : text_fields
      text_fields = %w(brand^7 lone_title^8 taxons^5 genders^3 other_text^3) unless text_fields.present?

      logger.debug "|> Query Given >>#{query}<<"
      # match all documents
      if query.blank? && filters.blank?
        @search_definition[:query] = { match_all: {} }
      else
        query_hash =
          if query.blank?
            nil
          elsif query.strip.starts_with?('{')
            eval(query)
          else
            query_type_match = /\A((multi_match|dis_max):)?(.+)/.match(query)
            query_type = query_type_match[2] || DEFAULT_SEARCH_TYPE
            actual_query = query_type_match[3]
            if query_type == 'dis_max'
              { dis_max:{
                queries: split_query_per_text_field(text_fields, actual_query),
                tie_breaker: 0.7
              }
            }
          elsif query_type == 'multi_match'
            { multi_match: { query: actual_query, fuzziness: 0, fields: text_fields } }
          elsif query_type == 'new_search'
            [ { multi_match: { query: actual_query, fields: text_fields, type: "best_fields", operator: :or, slop: 2, tie_breaker: 0.3 } },
              { multi_match: { query: actual_query, fields: text_fields, fuzziness: "AUTO", boost: 0.5 } } ]
          end
        end
        logger.debug "|> query_hash #{query_hash}"

        if query.present? && script_score_source.present?
          if query_type != 'new_search'
            @search_definition[:query] = make_function_score_query(query_hash, script_score_source)
          else
            @search_definition[:query] = make_new_function_score_query(query_hash, script_score_source)
          end
          logger.debug "|> search_definition #{@search_definition}"
        else ##############
          set_filters.call :must, query_hash if query_hash
        end
      end

      specified_filter = filters.delete(:filter)
      set_filters.call :must, specified_filter if specified_filter

      must_not_filter = filters.delete(:except)
      set_filters.call :must_not, must_not_filter if must_not_filter

      # logger.debug "| filters after: #{filters}"
      filters.each_pair do|field, value|
        if value.is_a?(Hash)
          set_filters.call field, value
        elsif value.is_a?(Array)
          multi_conditions = value.delete_if(&:blank?).collect do|v|
            { term:{ field => v } }
          end
          set_filters.call :filter, { bool: { should: multi_conditions } } if multi_conditions.size > 0
        else
          set_filters.call :filter, { term: { field => value } }
        end
      end

      if highlight && highlight.size > 0
        @search_definition[:highlight] = {
            pre_tags: highlight[0], post_tags: highlight[1] || '', fields: { predicate_text: {}, name: {} }
        }
      end


      yield @search_definition, text_fields, script_score_source if block_given?

      es.search(@search_definition)
    end

    ##
    # @highlight <Array of at least 1> 1st element being tag before matched text, and 2nd element being after.
    def self.suggest(query, filters = {}, highlight = [])
      # a lambda function adds conditions to a search definition
      set_filters = lambda do |context_type, filter|
        @search_definition[:query][:bool][context_type] |= [filter]
      end

      @search_definition = make_basic_search_definition.merge(size: 100)

      # match all documents
      if query.blank?
        set_filters.call(:must, match_all: {})
      else
        set_filters.call(
          :must,
          match: { predicate_text: { query: query, fuzziness: 0 } },
        )
      end

      if highlight && highlight.size > 0
        @search_definition[:highlight] = {
            pre_tags: highlight[0], post_tags: highlight[1] || '', fields: { predicate_text: {}, name: {} }
        }
      end

      logger.debug "| ES suggest: #{@search_definition}"

      es.search(@search_definition)
    end

    def self.completion(query)
      @search_definition = {
        suggest: {
          'song-suggest': {
            prefix: query,
            completion: {
              field: :name
            }
          }
        }
      }
      __elasticsearch__.search(@search_definition)
    end

    ##
    # Change of this should update scope search_indexable
    def indexable?


      ## This one of the most important pieces of code in the entire project. Please use caution when changing the logic of "indexable?"
      #fail safe check of iqs > 0 to add to index.
      ## Possibly where to put error checking for values related to search and sort.
      !available_on.nil? && self.slave_products.size == 0 && iqs.to_i > 0 && iqs.to_i > Spree::Product::TEST_IQS && (status_code.nil? || status_code.to_i < Spree::RecordReview::MAX_ACCEPTABLE_STATUS_CODE)
    end

    ##
    # Separate brand away from general option values like colors, sizes
    # @return [Hash] w/ keys: :brand, :option_values
    def searchable_option_values_map
      unless @searchable_option_values_map
        @searchable_option_values_map = {}
        option_values_s = ''
        brand_id = Spree::OptionType.brand.id

        # Collect all brands
        brands = []
        brand_score = []

        # Iterate over option values
        self.hash_of_option_type_ids_and_values(true, true).values.each do |option_values|
          option_values.each do |ov|
            if ov.option_type_id == brand_id
              brands << ov.presentation.strip
              # Coerce extra_value to 0 if nil or non-numeric
              brand_score << ov.extra_value.to_i
            elsif !ov.one_value?
              option_values_s << ' ' + ov.presentation
            end
          end
        end

        # Add up to 3 brands to the map
        brands.first(3).each_with_index do |brand, index|
          @searchable_option_values_map[:"brand_#{index + 1}"] = brand
          if brand_score[index] # Check if the index exists in brand_score
            @searchable_option_values_map[:"brand_#{index + 1}_value"] = brand_score[index].to_i
          else
            @searchable_option_values_map[:"brand_#{index + 1}_value"] = 0 # Default to 0 if out of bounds
          end
        end

        # Safely calculate total brand value (sum of extra_values)
        @searchable_option_values_map[:brand_value] = brand_score.compact.map(&:to_f).reduce(0, :+)

        # Combine all brands into a single field
        @searchable_option_values_map[:brand] = brands.join(' ')

        # Add general option values
        @searchable_option_values_map[:option_values] = option_values_s
      end

      @searchable_option_values_map
    end

    def taxons_text(&block)
      words = Set.new
      self.taxons.each do|t|
        if t.depth > 0
          t.categories_in_path.each do|cat|
            cat.name.split_to_title_words.each do|w|
              yield w if block_given?
              words << w
            end
          end
        end
      end
      words.to_a.join(' ')
    end

    def brand_option_value_ids
      brand_id = Spree::OptionType.brand.id

      # Fetch the hash of option type IDs to their associated option values
      option_type_id_to_values = self.hash_of_option_type_ids_and_values

      # Find the array of Spree::OptionValue objects that are associated with the brand_id
      brand_option_values = option_type_id_to_values[brand_id.to_s] || []

      # Extract the IDs from the Spree::OptionValue objects
      brand_option_value_ids = brand_option_values.map(&:id)

      brand_option_value_ids
    end

    def predicate_text
      name + ' ' + taxons_text
    end

    def as_indexed_json(options = {})
      json = self.as_json(except: [:available_on, :updated_at, :deleted_at, :promotionable, :slug,
        :tax_category_id, :shipping_category_id, :last_review_at, :master_product_id, :engagement_count, :status_code, :images_count, :discontinue_on,
         :rep_variant_id, :rep_variant_set_by_admin_at])
      json[:price] = self.price
      json[:taxon_ids] = self.taxons.collect{|t| t.depth > 1 ? t.categories_in_path.collect(&:id) : t.id }.flatten.uniq

      # Generate `other_text`
      other_text = name.clone.downcase

      # Append `meta_title` to `other_text` if not already present
      if meta_title.present?
        meta_title_downcased = meta_title.downcase
        unless other_text.include?(" #{meta_title_downcased} ") ||
               other_text.start_with?("#{meta_title_downcased} ") ||
               other_text.end_with?(" #{meta_title_downcased}")
          other_text += " #{meta_title_downcased}"
        end
      end

      json[:genders] = taxons.all.collect(&:genders).join(' ')
      json[:lone_title] = taxons.collect{|t| t.meta_keywords.to_s.gsub(',', ' ') }.reject(&:blank?).join(' ')
      json[:taxons] = taxons_text
      if taxons.present? && taxons.first.present? && taxons.first.weight.present?
        json[:taxon_weight] = taxons.first.weight
      else
        json[:taxon_weight] = 0
      end

      json[:option_type_ids] = product_option_types.collect(&:option_type_id)
      json[:option_value_ids] = variants_including_master_without_order.includes(:option_value_variants).all.collect{|v| v.option_value_variants.collect(&:option_value_id) }
      json.merge!( self.searchable_option_values_map )


      ####################################################################################################################################
      #   This handles the stemming, striping, and deduplication of other_text to not have words from taxon, lone title, brands, or banned phrases
      ####################################################################################################################################

      # Combine all words into a single string and split into an array of words
      all_words = "#{json[:genders]} #{json[:lone_title]} #{json[:taxons]}".downcase.split

      # Stem all words to match different forms (like bags and bag)
      # Only perform stemming in staging and production
      if Rails.env.production? || Rails.env.staging?
        # Stem all words to match different forms (like bags and bag)
        stemmed_words = all_words.map(&:stem)
      else
        # Use unstemmed words in other environments
        stemmed_words = all_words
      end

      # Remove the stemmed words from other_text
      stemmed_words.each do |word|
        # Match stemmed words with optional word characters following them
        other_text.gsub!(/\b#{Regexp.quote(word)}\w*\b/, ' ')
      end

      # Handle brands
      if brands.present?
        brands.each do |b|
          brand_name = b.presentation&.downcase

          if brand_name.present?
            # Split multi-word brands into separate words
            brand_parts = brand_name.split

            brand_parts.each do |part|
              # Remove brand parts, matching whole words and appended characters
              other_text.gsub!(/\b#{Regexp.quote(part)}\w*\b/i, ' ')
            end

            # Match the concatenated form of the brand name
            concatenated_brand = brand_parts.join
            other_text.gsub!(/#{Regexp.quote(concatenated_brand)}\w*/i, ' ')
          end
        end
      end

      # Handle banned phrases
      banned_phrases = ["lv", "gg", "cc", "ysl", "louis", "vuitton", "guccy"] # Add more phrases as needed
      banned_phrases.each do |phrase|
        # Match banned phrases with optional spaces and remove them
        other_text.gsub!(/\b#{Regexp.quote(phrase)}\b/i, ' ')
      end

      # Strip partial brand matches (e.g., '#gucci' -> '#')
      if brands.present?
        brands.each do |b|
          brand_name = b.presentation&.downcase

          if brand_name.present?
            # Remove brand names even as partial matches, preserving surrounding characters
            other_text.gsub!(/#{Regexp.quote(brand_name)}/i, '')
          end
        end
      end

      # Deduplicate words in other_text
      unique_words = other_text.split.map(&:strip).uniq
      other_text = unique_words.join(' ')

      # Remove extra spaces created during replacements
      other_text.strip!


      ####################################################################################################################################
      # Clean up extra spaces and assign to json
      json[:other_text] = other_text&.squish
      ####################################################################################################################################

      # Clean up extra spaces and assign to json
      json[:other_text] = other_text&.squish

      json[:predicate_text] = predicate_text

      json[:best_price] = best_price_record&.price
      json[:transaction_count] = transaction_count || calculate_transaction_count
      json[:recent_transaction_count] = recent_transaction_count
      json[:recent_view_count] = recent_view_count
      adopters = adopter_user_ids
      json[:viable_adopter_count] ||= adopters.size
      json[:adopter_user_ids] = adopters
      json[:last_transaction_time] = last_completed_order&.completed_at
      json
    end

    ##
    # Override of elasticsearch-model
    def index_document(options={})
      return {} unless indexable?

      __elasticsearch__.index_document
    end

    ##
    # Enforces full reindex.  es.update_document fails when called by before or after calls
    # because @__changed_model_attributes existing would only update those attributes but
    # not other values in as_indexed_json; for example, change of taxons would not update.
    def reindex_document
      if indexable?
        begin
          __elasticsearch__.delete_document
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
        end
        __elasticsearch__.index_document
      else
        begin
          __elasticsearch__.delete_document
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
        end
      end
    end

    def related_products(other_options = {})
      # Initialize the must conditions array
      must_conditions = []

      # Add taxon condition if taxons are present
      must_conditions << { terms: { taxon_ids: [taxons.first.id] } } if taxons.first

      #Gets the brands for this item
      brand_option_values_ids = brand_option_value_ids

      # Ensure we add the option_value_ids condition only if the array is not empty
      unless brand_option_values_ids.empty?
        must_conditions << { terms: { option_value_ids: brand_option_values_ids } }
      end

      # Construct the Elasticsearch query
      query = {
        size: 8,
        sort: [{ _score: { order: "desc" } }],
        query: {
          bool: {
            must_not: [{ terms: { "_id": [id.to_s] } }],
            should: [{
              function_score: {
                query: {
                  bool: {
                    must: must_conditions,
                    should: [
                      { multi_match: { query: name, fields: ["brand^3", "lone_title^6", "gender^3", "other_text"], type: "best_fields", tie_breaker: 1.0 }},
                      { multi_match: { query: name, fields: ["brand^3", "lone_title^6", "gender^3", "other_text"], type: "phrase", boost: 2 }}
                    ]
                  }
                },
                script_score: {
                  script: {
                    source: "return _score + Math.log(doc['recent_transaction_count'].value + 1) + Math.log10(doc['recent_view_count'].value + 1) + (doc['iqs'].value * 4) + (doc['curation_score'].value * 6)",
                    lang: "painless"
                  }
                }
              }
            }]
          }
        }
    }

  # Perform the search with the constructed query
  searcher = Spree::Product.es.search(other_options.merge(query))
  logger.debug "| related_products searcher def: #{searcher.search.definition}"
  searcher
end




    def self.make_basic_search_definition
      # Query DSL https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html
      {
        query: {
          bool: {
            must: [],
            should: [],
            filter: []
          }
        }
      }
    end


    def self.make_new_search_definition
      # Construct the query using multi_match and function score
         {
           query: {
             bool: {
               should: [
                 {
                   multi_match: {
                     query: [],
                     fields: [],
                     type: [],
                     tie_breaker: 1.0
                   }
                 },
                 {
                   multi_match: {
                     query: [],
                     fields: [],
                     type: "phrase",
                     boost: []
                   }
                 },
                 {
                   match_phrase: {
                     brand: {
                       query: [],
                       boost: 6.0
                     }
                   }
                 }
               ],
               minimum_should_match: 1
             }
           }
         }
    end

    ##
    # Parameter :sort might be given worded sort order, for example, "price-low-to-high"
    # @return [Array of Hash(ES_attribute => { order: asc or desc} )]
    def self.make_sort_order(sort, text_query = nil)
      order = nil
      if sort.present?
        sort.gsub!(/([\-\+]+)/, ' ')
        sort.downcase!
        if sort == 'price low to high'
          order = [ {'price': { order: 'asc' } }, {'_id': { order: 'desc'} } ]
        elsif sort == 'price high to low'
          order = [ {'price': { order: 'desc' } }, {'_id': { order: 'desc'} } ]
        elsif sort == 'newest first'
          order = [ {'_id': { order: 'desc'} } ]
        elsif sort == 'mostly viewed'
          order = [ {'view_count': { order: 'desc'} } ]
        elsif sort == 'adoption'
          order = [ {'curation_score': {order:'desc'} }, {'recent_transaction_count':{ order:'desc'} }, { '_id':{order:'desc'} }  ]
        elsif sort == 'most wanted'
          order = [ {'transaction_count': {order:'desc'} }, {'view_count':{ order:'desc'} }, { '_id':{order:'desc'} } ]
        elsif sort == 'most recent transacted'
          order = [ {'last_transaction_time': {order:'desc'} }, {'view_count':{ order:'desc'} }, { '_id':{order:'desc'} } ]
        else
          begin
            order = eval(sort)
          rescue Exception => sort_order_e
            logger.warn "** Error in parsing the given sort #{sort}: #{sort_order_e.message}"
          end
        end
      end
      #Category Browse Sort
      order ||= DEFAULT_NO_TEXT_SORT if text_query.blank?
      #Search Default Sort
      order ||= DEFAULT_SEARCH_SORT
      order
    end

    def self.make_function_score_query(query_hash, script_score_source)
      {
        function_score: {
          query: { bool: { must: query_hash } },
          script_score: {
            script: {
              source: script_score_source
            }
          }
        }
      }
    end

    def self.make_new_function_score_query(query_hash, script_score_source)
      #logger.debug "|> Query_Hash 1: #{query_hash}"
      #logger.debug "|> Query_Hash 2: #{query_hash_2}"

      {
        function_score: {
          query: {
            bool: {
              should: query_hash,
              "minimum_should_match": 1
            }
          },
          functions: [
            {
              script_score: {
                script: {
                  source: script_score_source
                }
              }
            }
          ],
          score_mode: :sum,
          boost_mode: :multiply
        }
      }
    end

    ##
    # Parse text_fields list to look by boost syntax "brand^", and place that
    # as :boost value to query setting.
    # if $ preceeds the fieldname, creates constant_score function for boolean either/or matching
    def self.split_query_per_text_field(text_fields, keyword_query)
      text_fields.collect do|field|
        field_m = /\A([^\^]+)(\^([\d\.]+))?\b/.match(field)
        boost = (field == 'option_values') ? 1.0 : [ field_m[3].to_f, 1.0 ].max
        if(field_m[1].chars.first == '$')
          {constant_score: { filter: { match: { field_m[1][1..-1] => keyword_query }}, boost: boost }}
        else
          {match:{ field_m[1] => {query: keyword_query, boost: boost }} }
        end
      end
    end

    ##
    # Filtered to import only 'search_indexable'.  Different from es.rebuild_index!
    # that indices all regardless of 'indexable?'.
    def self.rebuild_index!(run_import = true)
      begin
        es.delete_index!
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        puts '** Index NotFound'
      end
      es.create_index!
      self.import scope: 'search_indexable' if run_import
    end

    def self.reindex(force_reindex = true, &block)
      batch_no = 1
      Spree::Product.search_indexable.in_batches(of: 100, start: 0) do|batch_q|
        batch_start_time = Time.now
        puts "  reindexing batch #{batch_no} at #{batch_start_time.to_s(:db)}"
        batch_q.includes_for_indexing.each do|p|
          if force_reindex
            p.reindex_document
          else
            p.index_document
          end
        end
        yield batch_no
        batch_end_time = Time.now
        puts "    batch #{batch_no} took #{(batch_end_time - batch_start_time) / 1.second} seconds"
        sleep(5)
        batch_no += 1
      end
    end
  end # included
end
