##
# Define methods for searching and browsing products.
module ControllerHelpers
  module ProductBrowser
    extend ActiveSupport::Concern

    included do
      # before_action :set_taxons_info
    end

    def reset_params
      params.permit(:q, :query, :query_type, :keywords, :filter, :script_score_source, :page, :per_page, :limit, :sort, :sort_by, :search, :user_id, :taxon, :price, :menu_open, :taxon_ids, :option_type_ids, :option_value_ids, :reload_products, :sid)
      if request.path =~ /\A\/(search\/items|si|i|c)\/([\w\+])+/
        escaped_space_regex = /([\+\-\._]+)/
        params[:keywords].gsub!(escaped_space_regex, ' ') if params[:keywords].present?
        params[:query].gsub!(escaped_space_regex, ' ') if params[:query].present?
        if params[:item_id].present?
          if params[:item_id].to_i > 0 # only number
            redirect_to products_path(item_id: params[:item_id])
          else
            params[:keywords] = params[:item_id].gsub(/(\-\d+)\Z/, '').gsub(escaped_space_regex, ' ')
          end
        end
        if params[:category_id].present?
          params[:keywords] = [params[:keywords], params[:category_id].gsub(/(\-\d+)\Z/, '').gsub(escaped_space_regex, ' ') ].compact.join(' ')
        end
      end
    end

    ##
    # Keyword query
    def query
      @query ||= params[:q] || params[:query] || params[:keywords]
      params[:query_type].present? ? (params[:query_type] +':'+ @query ) : @query
    end

    ## Loads a search preset is sid is in the query.
    def load_search_preset
      return unless params[:sid].present?

      preset = SearchQueryPreset.find_by(identifier: params[:sid])
      return unless preset

      JSON.parse(preset.es_json).symbolize_keys
    rescue JSON::ParserError
      nil
    end

    # Preload in ActiveRecord query
    PRODUCT_SEARCH_RESULT_INCLUDES = [ :best_variant, { master: :images }, { master: :prices }, :option_types, :taxons ]

    def load_products_with_searcher
      params.permit!

      params[:taxon_ids] = params[:taxon_ids].to_a + [params.delete(:taxon_id)] if params[:taxon_id]
      @taxons = Spree::Taxon.where(id: params[:taxon_ids]) if params[:taxon_ids].present?

      filters = params.slice(*Spree::Product::FILTER_ATTRIBUTES).to_h.symbolize_keys
      filters.merge!(must_not: { term: { user_id: spree_current_user.try(:id) } }) if spree_current_user && !spree_current_user.admin?
      unless spree_current_user&.admin?
        filters.delete(:script_score_source)
        filters.delete(:text_fields)
        filters.delete(:search_override)
        filters.delete(:sort)
      end

      if params[:sid].present?
      preset = SearchQueryPreset.find_by(identifier: params[:sid])
      logger.debug "|> SearchQueryPreset (#{preset})"
      if preset
        # Parse the es_json from the preset and perform the search
        search_override = preset.es_json
        @searcher = ::Spree::Product.search(search_override, filters, [], search_override)
        # Handle the case where the preset is not found; you might want to redirect or show a fallback
        else
        end
      end

      # The search_override condition
      if params[:search_override].present?
        search_override = params[:search_override]
        @searcher = ::Spree::Product.search(params[:q], filters, [], search_override)
      elsif !params[:sid].present?
        # Original logic for constructing the search query when search_override is not present
        @searcher = ::Spree::Product.search(query, filters) do |search_def, text_fields, script_score|
          params[:text_fields] = text_fields.join(' ') if params[:text_fields].blank? && text_fields
          params[:script_score_source] = script_score if params[:script_score_source].blank? && script_score
          @search_query = search_def
        end
      end

      h = @searcher.search.definition
      logger.debug "| Final search def (#{@searcher.results.total}) #{h}"

      @searcher = @searcher.page(params[:page] || 1).limit(params[:limit] || 36)
      @products = @searcher.records(includes: PRODUCT_SEARCH_RESULT_INCLUDES)

      ## Fallback search with no results. Removed with addition of new search on 3/18/24
      #if @products.blank? && @searcher.results.total == 0 && !params[:search_override].present?
        ### Fallback search when no results are found
        #filters[:text_fields] = 'other_text' # Adjusted for fallback scenario
        #@searcher = ::Spree::Product.search(params[:q], filters).page(params[:page] || 1).limit(params[:limit] || 28)
        #@products = @searcher.records(includes: PRODUCT_SEARCH_RESULT_INCLUDES)
      #end

      @products
    end

    ##
    # Using ElasticSearch to get aggregations of current taxon and its children.
    def taxon_aggregations(taxon = nil)
      taxon ||= Spree::CategoryTaxon.root
      tids = [taxon.id]
      taxon.children.includes(:children).each do|subc|
        tids += [subc.id]
      end
      logger.debug "| tids: #{tids}"
      search = ::Spree::Product.search(nil, {taxon_ids: tids}, [], { taxon_ids:'taxon_ids' }) do|definition|
        # logger.info "| def #{definition}"
      end
      h = {}
      search.aggregations[:taxon_ids].try(:fetch, :buckets, []).to_a.each do|bucket|
        found_taxon_id = bucket[:key]
        h[ found_taxon_id ] = bucket[:doc_count]
        logger.debug '| %-60s | %5d | %d => %d' % [Spree::Taxon.find(found_taxon_id).breadcrumb, found_taxon_id, bucket[:doc_count], h[found_taxon_id] ]
      end
      h
    end

    ##
    # Using database query.  Calculates self's and children's overall sums of products within self and descendants.
    # @taxon [Spree::Taxon] If not given, would be categories root
    # @return [Hash of those taxon_id w/ count of records]
    def taxon_counts_of_products(taxon = nil)
      taxon ||= Spree::CategoryTaxon.root
      h = {}
      h[taxon.id] = Spree::Classification.where(taxon_id: taxon.id).count
      taxon.children.each do|child|
        h[child.id] = Spree::Classification.where(taxon_id: child.self_and_descendants.collect(&:id) ).count
      end
      h[taxon.id] += h.values.sum
      h
    end

    ##
    # One before_action that sets @taxonomies and @taxon_counts_of_products
    def set_taxons_info
      @taxonomies = Spree::Taxonomy.includes(root: :children)
      if spree_current_user.try(:admin?)
        @taxon_counts_of_products ||= taxon_counts_of_products(@taxon)
        logger.info "| taxon counts: #{@taxon_counts_of_products}"
      end
    end

    LAST_REVIEWED_PRODUCT_IDS = 'buyer.products.last_reviewed_ids'
    LAST_VIEW_PRODUCT_REFERER = 'buyer.products.view_last_referer'
    MAX_REVIEWED_PRODUCT_IDS = 50

    ##
    #
    def set_view_data

      # Skip logging if the user is an admin or if the user is the owner of the product
      if spree_current_user && ( spree_current_user.admin? || spree_current_user.id == @product.id )
        return
      end

      return if params[:show_cart_form]

      # Precompiled regex for excluded IP prefixes
      excluded_ip_regex = /\A(157\.55|52\.167|66\.249|40\.77|207\.46|17\.241|192\.178)/

      # Get the request's IP address
      request_ip = request.remote_ip

      # Check if the request IP matches the excluded prefixes
      if request_ip =~ excluded_ip_regex
        logger.debug "Skipping logging for IP: #{request_ip} due to matching excluded prefix"
        return
      end

      # Handle product view counting and logging for non-excluded IPs
      product_ids = session[LAST_REVIEWED_PRODUCT_IDS].to_s.split(',').collect(&:to_i)

      if product_ids.exclude?(@product.id)
        @product.increment_view_count! # already has delayed

        ::RequestLog.save_request(request, user_id: spree_current_user.try(:id), group_name: 'view_product') unless spree_current_user&.admin? || spree_current_user&.test_or_fake_user?
        session[LAST_VIEW_PRODUCT_REFERER] = request.referer

        product_ids << @product.id
        s = product_ids[-1 * [product_ids.size, MAX_REVIEWED_PRODUCT_IDS].min, product_ids.size].collect(&:to_s).join(',')
        session[LAST_REVIEWED_PRODUCT_IDS] = s
      else
        logger.debug " .. already viewed #{@product.id}, view_count #{@product.view_count}"
      end
    end


    def load_sellers_data(product = @product)
      base_q = Rails.env.development? ? Spree::User : Spree::User.except_fake_users
      @sellers ||= base_q.left_joins(:ioffer_user).includes(:ioffer_user, store:[:store_payment_methods]).where(id: product.seller_ids ).distinct("#{Spree::User.table_name}.id").order('seller_rank desc')
    end

    ##
    #
    def load_latest_via_completed_orders(product_or_variant, limit = 4)
      @orders = Spree::Order.complete.joins(:line_items).not_by_unreal_users(:seller_user_id).
        joins(:seller).where("seller_rank >= ?", Spree::User::BASE_PENDING_SELLER_RANK).
        distinct('seller_user_id').order('completed_at desc')

      if product_or_variant.is_a?(Spree::Variant)
        @orders = @orders.where("variant_id=?", product_or_variant.id)
      elsif product_or_variant.is_a?(Spree::Product)
        @orders = @orders.where("product_id=?", product_or_variant.id)
      end
      @orders = @orders.uniq{|o| o.seller_user_id }
    end

    ##
    # Fetch only sellers that have this variant's combo of option values.
    # @return [Array of Spree::User] Would set the seller [Spree::User]
    #   variant or variant_adoption attribute w/ latest.
    def load_sellers_of_variant(variant)
      @sellers = variant.variant_adoptions.includes(:default_price).all.sort{|x,y| y.seller_based_sort_rank <=> x.seller_based_sort_rank }[0,1]
      @sellers
    end

    ##
    # Fetch only variants that have this variant's combo of option values.
    # Little more efficient than load_sellers_of_variant
    # @keep_users_unique: if true would check to get cheapest priced variant of each seller's multiple
    def load_related_variants(variant, keep_users_unique = true)
      unless @variants
        option_value_ids = variant.option_value_variants.collect(&:option_value_id).sort

        product_options_map = Spree::ProductOptionsMap.new(variant.product, nil, Spree::ProductOptionsMap::QUERY_INCLUDES_FOR_SORTING, exclude_zero_value: false)
        @variants = product_options_map[ option_value_ids ].to_a
        if keep_users_unique
          seller_id_to_price = {} # user_id => price
          @variants.each_with_index do|v, index|
            existing_price = seller_id_to_price[v.user_id]
            if existing_price && existing_price.to_f < v.price.to_f
              @variants.delete_at(index)
            else
              seller_id_to_price[v.user_id] = v.price
            end
          end
        end
      end
      @variants.reject!{|v| v.user_id.nil? || v.user.nil? }
      @variants
    end

    ##
    # TRX, CART, VCD, V2T, V2C, IQS
    # @return [HashWithIndifferentAccess]
    def load_product_stats(product = @product)
      unless @product_stats
        @product_stats = ActiveSupport::HashWithIndifferentAccess.new
        @product_stats['TRX'] = product.calculate_transaction_count
        @product_stats['CART'] = Spree::Order.with_product_id(product.id).where(state:'cart').count
        @product_stats['VCD'] = product.view_count.to_f / [1, ((Time.now - product.created_at) / 1.day) ].max
        @product_stats['V2T'] = product.view_count.to_f / [1, @product_stats['TRX'] ].max
        @product_stats['V2C'] = product.view_count.to_f / [1, @product_stats['CART'] ].max
        # @product_stats['V2C'] = product.view_count.to_f / MONEY_MADE
        @product_stats['IQS'] = product.iqs
      end
      @product_stats
    end

    LAST_PRODUCTS_SEARCH_URL = 'buyer.products.last_search_url'
    RECENT_PRODUCT_SEARCHES = 'buyer.products.recent_searches'

    ## Saves record of buyer's keyword search or SID click from homepage tiles.
    def save_buyer_tracks(search_results_count)

      # Get the request's IP address
      request_ip = request.remote_ip

      # Precompiled regex for excluded IP prefixes
      excluded_ip_regex = /\A(157\.55|52\.167|66\.249|40\.77|207\.46|17\.241|192\.178)/

      # Check if the request IP matches the excluded prefixes
      if request_ip =~ excluded_ip_regex
        logger.debug "Skipping saving search for IP: #{request_ip} due to matching excluded prefix"
        return
      end

      # Attempt to find a keyword or SID from the parameters
      kw_or_sid = [params[:keywords], params[:query], params[:sid]].find(&:present?)
      existing_keywords_or_sids = session[RECENT_PRODUCT_SEARCHES] || []

      if kw_or_sid && (spree_current_user.nil? || !spree_current_user&.admin?)
        if existing_keywords_or_sids.include?(kw_or_sid.downcase)
          logger.debug " .. already saved keyword/SID search #{kw_or_sid}"
        else
          logger.debug " .. saving keyword/SID search #{kw_or_sid}"
          # Assuming SID should be treated the same as keywords for logging
          SearchLog.create(
            user_id: spree_current_user.try(:id),
            ip: request.remote_ip,
            keywords: kw_or_sid,
            result_count: search_results_count,
            other_params: params.slice(:filter, :script_score_source, :user_id, :taxon, :price, :taxon_ids, :option_type_ids, :option_value_ids).as_json # Other interesting parameters
          )
          existing_keywords_or_sids << kw_or_sid.downcase
          session[RECENT_PRODUCT_SEARCHES] = existing_keywords_or_sids
        end
      end
    end


  end
end
