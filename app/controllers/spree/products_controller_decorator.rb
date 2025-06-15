##
# Partial override of original Spree::ProductsController.  Not necessary to rewrite whole
# class when most of codes are about the same.
module Spree::ProductsControllerDecorator

  def self.prepended(base)
    base.include ControllerHelpers::ProductBrowser
    base.include ::Spree::Admin::MoreOrdersHelper
    base.helper ::ControllerHelpers::ProductBrowser
    base.helper ::Spree::MoreProductsHelper
    base.helper ::Spree::ReviewsHelper

    base.before_action :reset_params, only: [:index, :suggest, :show_item_with_search_results]
    base.before_action :set_by_variant_id, only: [:show_by_variant]
    base.before_action :set_by_variant_adoption_id, only: [:show_by_variant_adoption]
    base.before_action :set_canonical_url_check, only: [:show_by_variant_adoption]
    # base.before_action :authenticate_spree_user! unless Rails.env.development? || Rails.env.test?
    #base.after_action :save_buyer_tracks, only: [:index]
    base.around_action :track_buyer_search, only: [:index]
  end


  def index
    @title = 'Products'
    if query.present?
      @title.prepend "#{query} - "
      set_meta_description("#{query.titleize} for Sale and Other Great Deals at iOffer")
    end

    load_products_with_searcher

    #@products contains the search results
    @search_results_count = @searcher.results.total || 0
    #save_buyer_tracks(@search_results_count)
  end

  def set_meta_description(description)
    @meta_description = description
  end

  ##
  # Rewrite to correct @product_images
  class Spree::ProductsController < Spree::StoreController
    def show
      if @product.status == 'invalid'
        flash[:alert] = t('product.this_product_is_unavailable')
        render_homepage
      else
        unless params[:action] =~ /\Ashow_by_/i || params[:id] == @product.friendly_id
          redirect_if_legacy_path
        else
          @taxon = params[:taxon_id].present? ? Spree::Taxon.find(params[:taxon_id]) : @product.taxons.first

          # Full page caching only for guests/buyers
          if !spree_current_user&.seller? && !spree_current_user&.admin?

            set_view_data

            # cache_key = "product_page/#{@product.id}/#{@product.updated_at.to_i}"
            #
            # if !Rails.env.staging? and (cached_page = Rails.cache.read(cache_key))
            #   render html: cached_page.html_safe and return
            # end

            # Only reach here if cache is empty, now generate the full HTML
            load_variants
            @product_summary = Spree::ProductSummaryPresenter.new(@product).call
            @product_properties = @product.product_properties.includes(:property)
            @product_price = @product.best_variant.try(:price_in, current_currency).try(:amount)
            @product_price ||= @product.price_in(current_currency).amount
            @product_images = @product.variant_images.with_attached_attachment.includes(viewable:[:blob])

            rendered_page = render_to_string(template: 'spree/products/show', layout: 'spree/layouts/spree_application')

            #Rails.cache.write(cache_key, rendered_page, expires_in: 30.days)

            render html: rendered_page.html_safe
          else
            # Admin/Seller View (No Caching)
              load_variants
              @product_summary = Spree::ProductSummaryPresenter.new(@product).call
              @product_properties = @product.product_properties.includes(:property)
              @product_price = @product.best_variant.try(:price_in, current_currency).try(:amount)
              @product_price ||= @product.price_in(current_currency).amount
              load_sellers_of_variant(@variant || @product.master)
              load_latest_via_completed_orders(@variant || @product.master, 4)
              load_product_stats
              @transactions_recent_weeks = txns_per_time_period(1.week, 12, with_product_id: @product.id)
              @product_images = @product.variant_images.with_attached_attachment.includes(viewable: [:blob]) || []
              respond_to do |format|
                format.html { render template: 'spree/products/show_admin' }
              end
          end
        end
      end
    end
  end


  def show_by_variant
    logger.debug "| actual product is #{params}"
    load_product
    show && return
  end

  def show_by_variant_adoption
    logger.debug "| actual product is #{params}"
    load_product
    show && return
  end

  def get_item_reviews
    # Get the variant_adoption based on the display_variant_adoption_code
    @variant_adoption = Spree::VariantAdoption.includes(:variant).find_by(code: @product.display_variant_adoption_code)

    # Get item_reviews for that variant_adoption
    @item_reviews = @variant_adoption.present? ? @variant_adoption.item_reviews : []
  end


  def track_buyer_search
    yield # Allow the action to execute

    save_buyer_tracks(@search_results_count) if @search_results_count.present?
  end

  ##
  # Currently only sellers that have specified variant's combo of option values.
  def variant_data
    if (@variant = Spree::Variant.includes(:product, :option_value_variants).find_by(id: params[:id] ))
      load_sellers_of_variant(@variant)
      load_latest_via_completed_orders(@variant, 4)

      logger.debug "| loaded how many sellers? #{@sellers&.size}, orders #{@orders.size}"

      respond_to do|format|
        format.js
      end
    else
      respond_to do|format|
        format.js { render text:'' }
      end
    end
  end

  ###############################
  # Search actions

  ##
  # The old /i/item-title-1234 that would refer to old item ID system.  Instead
  # this would do full title search, and show 1st result as product detail.
  def show_item_with_search_results
    load_products_with_searcher
    @products = @products.to_a unless @products.is_a?(Array)
    @product = @products.shift

    @page_title = @title = params[:item_id].titleize if params[:item_id].present?

    @taxon = params[:taxon_id].present? ? Spree::Taxon.find(params[:taxon_id]) : @product.taxons.first

    @product_summary = Spree::ProductSummaryPresenter.new(@product).call
    @product_properties = @product.product_properties.includes(:property)

    load_variants

    @product_price = @product.best_variant.try(:price_in, current_currency).try(:amount)
    @product_price ||= @product.price_in(current_currency).amount

    @product_images = @product.variant_images.with_attached_attachment.includes(viewable:[:blob])
  end

  def suggest
    @results = Spree::Product.suggest( params[:query], {}, params[:highlight] || [])

    #@results = Spree::Product.suggest_aggregate(response, [:name], )
    # @results = Spree::Product.completion( params[:query] )

    respond_to do|format|
      format.js
    end
  end

  def set_canonical_url_check
    #load product if not available.
    load_product
    if @product
      p_canonical_code = @product.canonical_code
      p_canonical_url = @product.canonical_url

      #nil check then compare the vp code to the current url object
      return if p_canonical_code.blank?
      logger.debug "===> checking matching of #{p_canonical_url}#{p_canonical_code} and #{request.original_url}"

      response.headers['Link'] = "<#{canonical_url_for(@product)}>; rel=\"canonical\"" unless canonical_url_matches?(p_canonical_url, p_canonical_code, request.original_url)

      # set_canonical_url(p_canonical_url) unless canonical_url_matches?(p_canonical_url,request.original_url)
    end
  end

  def canonical_url_matches?(canonical_url, canonical_code, current_url)
    # Extract the unique identifier from the canonical URL.
    # Assuming the unique identifier is always at the end following a '-' character.

    #This should return true if you are on the canonical_url page. That happens now if you are on the Google or Bing (downcased) urls

    logger.debug "===> #{canonical_url}#{canonical_code} vs #{current_url}"

    return if canonical_code.blank?

    if current_url && canonical_url && canonical_code
      full_canonical = canonical_url.to_s + canonical_code.to_s
      current_url.downcase.include?(full_canonical.downcase)
    else
      return
    end

    #Old way with canonincal_url containing FULL url to canonical without having them split.
    ##  unique_id = if canonical_url.include?('-')
            ##  canonical_url.split('-').last
          ##  else
          ##    canonical_url
          ##  end

    # check is the unique_id is blank, meaning canonical_url is malformed or missing.
    # logger.debug "===> #{unique_id}"

    # Check if the unique ID from the canonical URL is included in the current URL.
    # urrent_url.include?(unique_id)
  end

  def canonical_url_for(product)

    return if product.canonical_code.blank?
    logger.debug "===> Set canonical url: http://#{request.host+"/vp/"+product.canonical_url+product.canonical_code}"
    # Create global var to store the formatted full canonical url in to be used in the view.
    canonical_url = "http://#{request.host+"/vp/"+product.canonical_url+product.canonical_code}"
  end

  def exists_in_search
    load_product
    @exists_in_search = @product ?
      (Spree::Product.search(nil, { _id: @product.id } ).results.total > 0) : false
    Spree::Product.es.search(query:{ bool:{
      must_not: [{ term:{ _id: p.id } }],
      should:
        p.taxons.first.categories_in_path.collect{|c| { term:{ taxon_ids: c.id }  }  } +
        [ { match:{ predicate_text: t } } ]
    } }, size: 8).records.map_with_hit{|_p, hit| [hit._score, _p.id, _p.name] }
  end

  ##
  # Different from method related which depends on @product.has_related_products?
  # /products/1234/related.js?container=cssSelector
  def related_products
    load_product
    if @product
      @products = @product.related_products(size: 8).records
      logger.debug "| related_products: #{@products.size}"
      respond_to do|format|
        format.html { render template:'spree/products/index', locals: { is_related: true  } }
        format.js
        format.json { render json: @related_products_search.results.collect(&:as_json) }
      end
    else
      respond_to do|format|
        format.html { '/404' }
        format.js { render js:'' }
        format.json { render json:[] }
      end
    end
  end

  private

  def set_by_variant_id
    if params[:variant_id] =~ Spree::Product::SLUG_REGEXP
      @variant = Spree::Variant.find_by(id: $2)
      if @variant&.product_id
        params[:id] = @variant.product_id
      else
        flash[:error] = I18n.t('errors.product.this_item_removed') || 'This item has been removed'
        redirect_to home_path(error:'item_removed')
      end
    else
      redirect_to '/404'
    end
  end

  def set_by_variant_adoption_id
    if params[:variant_adoption_id] =~ Spree::VariantAdoption::SLUG_REGEXP
      @variant_adoption = Spree::VariantAdoption.includes(:variant).find_by(code: $2)
      if (product_id = @variant_adoption&.variant&.product_id )
        params[:id] = product_id
      else
        flash[:error] = I18n.t('errors.product.this_item_removed') || 'This item has been removed'
        redirect_to home_path(error:'item_removed')
      end
    else
      redirect_to '/404'
    end
  end

  ##
  # Override.  Optimize some has_many association queries.
  def load_product
    @products = if try_spree_current_user.try(:has_spree_role?, 'admin')
                  Spree::Product.with_deleted
                else
                  Spree::Product.where(nil)
                end

    @product = @products.includes(master:[:prices, images:[:viewable] ] ).
               friendly.
               find(params[:id])
  end

  ##
  # Override.  More includes ahead of time, such as use of product_variants_matrix
  # Expect new variant to variant adoptions structure to keep only unique combos of option values.
  def load_variants
    @variants = @product.
      variants_including_master_without_order.where(converted_to_variant_adoption: false).spree_base_scopes.active(current_currency).
      includes(:default_price, :prices, :option_values, user:[:role_users], preferred_variant_adoption:[:prices],
        images:{ attachment_attachment:[:blob] })
  end

end

::Spree::ProductsController.prepend(::Spree::ProductsControllerDecorator) if ::Spree::ProductsController.included_modules.exclude?(::Spree::ProductsControllerDecorator)
