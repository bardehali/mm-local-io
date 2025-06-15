module Spree::Admin::Shared::AdoptionHelper

  DEFAULT_PAGE_LIMIT = 36

  ##
  # Loads the necessary option types, taxons, and thus products for seller to
  # make their own variants of.
  def load_products_for_adoption
    params.permit!
    page_limit = params[:limit] || DEFAULT_PAGE_LIMIT

    @selling_taxons =
      if (taxon_id = params[:taxon_id].to_i) > 0
        Spree::Taxon.where(id: taxon_id).all
      elsif spree_current_user && !spree_current_user.admin?
        spree_current_user.selling_taxons
      else
        []
      end
    logger.debug "| selling_taxons #{@selling_taxons.to_a.collect(&:name)}"
    selling_taxon_ids = Set.new
    @selling_taxons.each do|selling_t|
      selling_t.self_and_descendants.each do|t|
        selling_taxon_ids << t.id
      end
    end

    select_list = "distinct(#{Spree::Product.table_name}.id) as id, `#{Spree::Product.table_name}`.`name`, `#{Spree::Product.table_name}`.`description`, `#{Spree::Product.table_name}`.`deleted_at`, `#{Spree::Product.table_name}`.`slug`, `#{Spree::Product.table_name}`.`created_at`, `#{Spree::Product.table_name}`.`user_id`, `#{Spree::Product.table_name}`.`master_product_id`, `#{Spree::Product.table_name}`.`retail_site_id`, `#{Spree::Product.table_name}`.`iqs`"

    @collection = ::Spree::Product.select(select_list).where('last_review_at IS NOT NULL').order('iqs desc').page(params[:page] || 1).per(page_limit)
    @collection = @collection.where("1 > 2") if params[:q] == 'second' # simply skip 1st query
    unless spree_current_user.admin?
      listed_product_ids = Spree::Variant.select('distinct(product_id)').where(user_id: spree_current_user.id).collect(&:product_id)
      @collection = @collection.where("#{Spree::Product.table_name}.id NOT IN (?)", listed_product_ids ) if listed_product_ids.present?
    end
    if selling_taxon_ids.size > 0
      @collection = @collection.joins(:classifications).
        where(Spree::Classification.table_name => { taxon_id: selling_taxon_ids } )
    end
    if params[:option_value_id]
      @collection = @collection.joins(variants_including_master: :option_value_variants ).
        where(variants_including_master:{ spree_option_value_variants:{ option_value_id: params[:option_value_id]} } )
    end

    logger.debug "adoption total #{@collection.count}"
    if params[:collection] == 'more' && @collection.count < page_limit
      logger.warn "* Not enough collection #{@collection.count}"
      product_ids_excluding = []
      @previous_collection = @collection.clone
      if @previous_collection.count > 0
        product_ids_excluding = @previous_collection.all.select("#{Spree::Product.table_name}.id").collect(&:id)
      end
      @collection = ::Spree::Product.select(select_list).order('iqs desc').page(params[:page] || 1).per(page_limit)
      @collection = @collection.where("#{Spree::Product.table_name}.id NOT IN (?)", product_ids_excluding) if product_ids_excluding.size > 0
      @collection = @collection.by_other_users(spree_current_user.id ) unless spree_current_user.admin?
    end
    @collection
  end

  ##
  # Distinct list of products adopted, which means not created by user.
  # This uses ransack
  def load_products_adopted
    params[:q] ||= {}
    params[:q][:s] ||= "view_count desc"

    user_id = spree_current_user&.admin? ? params[:variant_adoptions_user_id_eq] : spree_current_user.id
    user_where_cond = nil
    if user_id
      @user = Spree::User.find_by_id(user_id)
      @page_title << " by #{@user.login}" if @user && @page_title && spree_current_user&.admin?
    end

    @search = Spree::Product.adopted_by(@user&.id).ransack(params[:q])
    @collection = @search.result(distinct: true).
        # includes(products_adopted_includes).
        page(params[:page]).
        per(Spree::Config[:admin_products_per_page] )

    logger.debug "| products#adopted.collection = #{@collection.to_sql}"
    @collection
  end

  def load_latest_wanted_products(taxon_id: nil)
    logger.debug "| Loading Wanted Products:::"
    product_ids = current_user_adopted_product_ids

    # Retrieve recent transactions with optional taxon filter
    # transactions = ::Spree::LineItem.joins(:order, product: :taxons)
    #   .where.not(product_id: product_ids.presence || [])
    #   .where("completed_at IS NOT NULL")
    #   .where(
    #     spree_products: {
    #       supply_priority: [1,2,3,4]
    #     }
    #   )
    #   .where(taxon_id ? { spree_taxons: { id: taxon_id } } : nil)
    #   .includes(product: [:taxons, { master: :images }])
    #   .order(params[:sort] || "completed_at DESC")
    #   .limit(100)

    transactions = ::Spree::LineItem.joins(:order, product: :taxons)
      .where.not(product_id: product_ids.presence || [])
      .where("completed_at IS NOT NULL")
      .where(taxon_id ? { spree_taxons: { id: taxon_id } } : nil)
      .includes(order: :seller, product: [:taxons, { master: :images }])
      .order(params[:sort] || "completed_at DESC")
      .limit(100)
      .select { |line_item| line_item.order&.is_phantom_seller? }

    # Filter to unique buyers by user_id within Ruby
    @recent_transactions_of_wanted_products = transactions.uniq { |line_item| line_item.order.user_id }

    # Apply pagination to the filtered set if needed
    @recent_transactions_of_wanted_products = Kaminari.paginate_array(@recent_transactions_of_wanted_products).page(params[:page] || 1).per(36)

    logger.debug "| phantom ordered products count: #{@recent_transactions_of_wanted_products.count}"
  end


  def get_latest_wanted_products(taxon_id = nil)
    logger.debug "| Loading Wanted Products:::"
    product_ids = current_user_adopted_product_ids

    # transactions = ::Spree::LineItem
    #   .joins(:order)
    #   .where("#{Spree::Order.table_name}.completed_at IS NOT NULL")
    #   .where.not(product_id: product_ids)
    #   .includes(product: [:taxons, { master: :images }])
    #   .where(
    #     spree_products: {
    #       supply_priority: [1,2,3,4]
    #     }
    #   )
    #   .order(params[:sort] || "completed_at DESC")
    #   .limit(100)

    transactions = ::Spree::LineItem.joins(:order, product: :taxons)
      .where.not(product_id: product_ids.presence || [])
      .where("completed_at IS NOT NULL")
      .where(taxon_id ? { spree_taxons: { id: taxon_id } } : nil)
      .includes(order: :seller, product: [:taxons, { master: :images }])
      .order(params[:sort] || "completed_at DESC")
      .limit(100)
      .select { |line_item| line_item.order&.is_phantom_seller? }

    # Conditionally add the taxon filter if `taxon_id` is present
    if taxon_id.present?
      transactions = transactions.select do |transaction|
        transaction.product.taxons.pluck(:id).include?(taxon_id)
      end
    end

    # Filter for unique buyers by user_id within Ruby
    unique_transactions = transactions.uniq { |line_item| line_item.order.user_id }

    # Paginate the unique results
    Kaminari.paginate_array(unique_transactions).page(params[:page] || 1).per(36)
  end

  def get_latest_sale_image_for_taxon(taxon_id = nil)
    #Define the base query to get the latest line item for completed orders with specific curation scores
    latest_line_item = ::Spree::LineItem
      .joins(:order)
      .where("#{Spree::Order.table_name}.completed_at IS NOT NULL")
      .joins(product: :taxons)
      .where(spree_products: { supply_priority: [1, 2, 3, 4] })
      .where("spree_taxons.id = :taxon_id OR :taxon_id IS NULL", taxon_id: taxon_id)
      .includes(product: { master: :images })
      .order("spree_line_items.created_at DESC")
      .limit(1)

    # #This is wrong for this method.
    # transactions = ::Spree::LineItem.joins(:order, product: :taxons)
    #   .where("completed_at IS NOT NULL")
    #   .where(taxon_id ? { spree_taxons: { id: taxon_id } } : nil)
    #   .includes(order: :seller, product: [:taxons, { master: :images }])
    #   .order(params[:sort] || "completed_at DESC")
    #   .limit(1)
    #   .select { |line_item| line_item.order&.is_phantom_seller? }

    # Conditionally filter by taxon if taxon_id is provided
    # latest_line_item = latest_line_item.where(spree_taxons: { id: taxon_id }) if taxon_id.present?

    # Retrieve the latest line item's first image, if available
    latest_line_item.first&.product&.master&.images&.first
  end


  def load_most_wanted_products
    blank_search = (params[:taxon_id].nil? && params[:keywords].blank? && params[:sid].blank? )

    if blank_search
       @wanted_searcher = ::Spree::Product.search(nil, build_search_filter_params ).page(params[:page] || 1).limit(36)
       logger.debug "| search definition: #{@wanted_searcher.search.definition}"
       @wanted_products = @wanted_searcher.records(includes:[ { master: :images }, :taxons ])
    end

    unless @wanted_products.present?

      product_ids = current_user_adopted_product_ids

      #Check if custom json id is prsent, use if it is, otherwise use the keyword/taxon search
      if params[:sid].present?
        preset = SearchQueryPreset.find_by(identifier: params[:sid])
        search_override = preset.es_json
        @wanted_searcher = ::Spree::Product.search(search_override, params, [], search_override).page(params[:page] || 1).limit(36)
        @wanted_products = @wanted_searcher.records(includes:[ { master: :images }, :taxons ])
      else
        @wanted_searcher = ::Spree::Product.search(params[:keywords], build_search_filter_params ).page(params[:page] || 1).limit(36)
        logger.debug "| search definition: #{@wanted_searcher.search.definition}"
        @wanted_products = @wanted_searcher.records(includes:[ { master: :images }, :taxons ])
      end
    end
    # Exclude adopted products
    @wanted_products = @wanted_products.where.not(id: product_ids) if product_ids.present?

    @wanted_products
  end

  ##
  # Mainly for homepage
  def cache_of_mostly_viewed_products(total_limit = 100, sub_limit = 40, should_randomize = true)
    cache_key = "products.ids_of_mostly_viewed.#{total_limit}"
    product_ids = Rails.cache.fetch(cache_key, expires_in: 1.day) do
      searcher = ::Spree::Product.search(nil, build_search_filter_params(false) ).page(1).limit(total_limit)
      searcher.records.collect(&:id)
    end
    sub_product_ids = (should_randomize ? product_ids.shuffle : product_ids)[0, sub_limit]
    Spree::Product.includes( { master: :images }, :taxons).where(id: sub_product_ids).all
  end

  private

  def products_adopted_includes
    [:variant]
  end

  def build_search_filter_params(exclude_current_user = true)
    @taxon = Spree::Taxon.find_by(id: params[:taxon_id]) if params[:taxon_id]
    params[:q] ||= {}
    filter_params = { sort: 'adoption', taxon_ids: [params[:taxon_id]].compact, curation_score: [80, 70, 60, 50] }

    # Except user's involved products
    if exclude_current_user && spree_current_user
      product_ids = current_user_adopted_product_ids
      filter_params[:except] = { terms: { '_id' => product_ids } } if product_ids.size > 0
    end

    filter_params
  end

  def current_user_adopted_product_ids
    if spree_current_user && !spree_current_user.admin?
      pids = Spree::Product.where(user_id: spree_current_user&.id).select('id').collect(&:id)
      pids += Spree::Variant.where(user_id: spree_current_user&.id).distinct(:product_id).select('product_id').collect(&:product_id)
      pids += Spree::VariantAdoption.joins(:variant).where(user_id: spree_current_user&.id).distinct("#{Spree::Variant.table_name}.product_id").select('product_id').collect(&:product_id)
      pids.uniq
    else
      []
    end
  end
end
