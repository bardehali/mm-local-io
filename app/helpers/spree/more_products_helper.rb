module Spree
  module MoreProductsHelper
    include BaseHelper
    extend ActiveSupport::Concern

    ##
    # Exact as Spree::BaseHelper
    def meta_data_tags
      meta_data.map do |name, content|
        tag('meta', name: name, content: content.html_safe) unless name.nil? || content.nil?
      end.join("\n")
    end

    ##
    # Different from Spree::BaseHelper
    def meta_data
      object = instance_variable_get('@' + controller_name.singularize)
      meta = {}

      return meta if object.nil?

      if @page_title.present? # instead of given @product
        meta[:keywords] = @page_title
      elsif object.is_a? ApplicationRecord
        meta[:keywords] = object.meta_keywords if object[:meta_keywords].present?
        meta[:description] = object.meta_description if object[:meta_description].present?
      end

      if meta[:keywords].blank? || meta[:description].blank?
        if object && (@page_title.present? || object[:name].present? )
          kws = @page_title.present? ? [@page_title] : [object.name]
          kws << object.brand if object.respond_to?(:brand)
          kws << object.taxons.first&.name + ' for Sale' if object.respond_to?(:taxons) && object.taxons.first
          kws.insert(1, 'and other') if kws.size > 1
          meta.merge!(
            keywords: [ kws.first, current_store.meta_keywords].reject(&:blank?).join(' '),
            description: kws.reject(&:blank?).join(' ')
          )
        else
          meta.reverse_merge!(keywords: (current_store.meta_keywords || current_store.seo_title),
                              description: (current_store.meta_description || current_store.seo_title) || "Discover fashion, sneakers, purses, accessories and more on the ultimate online marketplace. Shop unbeatable deals and enjoy free shipping on countless items. Your go-to destination for style and savings!")
        end
      end

      meta[:keywords].try(:squish!)
      meta[:description].try(:squish!)

      meta
    end

    ##
    # Alternative of Spree::BaseHelper#display_price to display master price if
    # default variant's price is 0.
    def display_variant_or_master_price(product_or_variant)
      price = nil
      if product_or_variant.is_a?(Spree::Product) && @variants
        price = @variants.sort_by(&:seller_based_sort_rank).last&.try(:price_in, current_currency)
      else
        price = product_or_variant.price_in(current_currency)
      end
      if price.nil? || price.price.to_f <= 0.0
        price = product_or_variant.is_a?(Spree::Product) ?
          product_or_variant.master.price_in(current_currency) : product_or_variant.product.master.price_in(current_currency)
      end
      price.display_price_including_vat_for(current_price_options).to_html
    end

    def display_median_price(product, favorable_payment_method_id = Spree::PaymentMethod.paypal&.id )
      product.median_price(nil, favorable_payment_method_id).display_price_including_vat_for(current_price_options).to_html
    end

    ##
    # @options
    #   :size [Integer] optional; default :mini; the image size version to show
    #   :itemprop [String] optional; HTML attribute
    #   :css_class [String] optional
    def image_holder(image, options = {})
      size = options[:size] || :small
      cls ||= options[:css_class].to_s

      image_url = image ? cdn_image_url(image, :pdp_thumbnail) : nil
      if image_url.present?
        if image_alt = image.try(:alt)
          image_tag image_url, alt: image_alt, itemprop: options[:itemprop], class: 'image-preview'
        else
          image_tag image_url, itemprop: options[:itemprop], class: cls
        end
      else
        content_tag(:span, class:"image-holder #{size}") { '' }
      end
    end

    ##
    # Override that of ProductsHelper
    def product_images(product, variants)
      variants.map(&:images).flatten
    end

    def extra_product_name(product, option_type_names_to_includes = [])
      s = truncate(product.name, length: 50)
      if spree_current_user.try(:admin?) && option_type_names_to_includes.present?
        option_type_ids = product.option_types.where(name: option_type_names_to_includes ).select('id').collect(&:id)
        option_values = product.master.option_values.where( option_type_id: option_type_ids ).all
        if option_values.size > 0
          s.insert(0, "(#{option_values.collect(&:presentation).join(', ')}) ")
        end
      end
      s
    end

    def all_selling_taxon_options
      taxons = @selling_taxons.to_a
      existing_tids = Set.new
      taxons.each do|t|
        t.selected = true
        existing_tids << t.id
      end
      Spree::CategoryTaxon.root.children.each do|t|
        next if existing_tids.include?(t.id)
        taxons << t
        existing_tids << t.id
      end
      taxons
    end

    ##
    # Master 'For All', and variants having SKU and filtered options_text
    # @exclusive_option_types [Array of either Spree::OptionType#id as Integer or #name ]
    def show_limited_options_text(variant, exclusive_option_types = [], limit = 2)
      s =''
      _option_values = variant.option_values.joins(:option_type).includes(:option_type).to_a
      exclusive_option_types << 'brand' unless variant.is_master
      if exclusive_option_types.present?
        _option_values.delete_if do|ov|
          if exclusive_option_types.first.is_a?(Integer)
            exclusive_option_types.include?(ov.option_type_id)
          else
            exclusive_option_types.include?(ov.option_type.presentation.downcase)
          end
        end
      end
      _option_values = _option_values[0, limit] if limit
      s << _option_values.collect{|ov| "#{ov.option_type.presentation}: #{ov.presentation}"}.join(', ')
      if variant.sku.present?
        s.insert 0, "SKU: #{variant.sku}, "
      end
      if s.blank? && variant.price.to_f > 0
        s = 'Price: $%.2f' % [variant.price]
      end
      if s.blank?
        s = variant.is_master ? '' : 'Created at %s' % time_ago_in_words( variant.created_at ) + ' ago'
      end
      s
    end

    ##
    # Ensure master variant is on top
    def variants_in_order(product, &block)
      variants =
        if spree_current_user.try(:admin?)
          product.variants_including_master.includes(:user, :option_values, variant_adoptions:[:default_price, user:[:role_users] ]).to_a
        elsif spree_current_user.try(:id) == product.user_id
          product.variants_including_master.by_this_user(product.user_id).includes(:option_values).to_a
        else
          product.variants.by_this_user(spree_current_user.id).includes(:option_values).to_a
        end
      variants.sort! do|x, y|
        if x.is_master
          -1
        elsif y.is_master
          1
        else
          x.option_values.size <=> y.option_values.size
        end
      end

      master_index = variants.index(&:is_master)
      if master_index.nil?
        variants.prepend(product.master)
      elsif master_index > 0
        master_variant = variants.delete_at(master_index)
        variants.prepend(master_variant)
      end
      variants
    end

    def description_rows_count
      if @admin_new
        2
      elsif @product.has_variants?
        15
      else
        22
      end
    end

    ##
    # @sort_order [String] default 'price'; other choices: 'seller_rank'
    # @return [Hash of Spree::PaymentMethod to cheapest Spree::Variant]
    def payment_method_for_variant(variant, sort_order = 'price')
      @payment_method_for_variant ||= {}
      h_of_sort = @payment_method_for_variant[sort_order] ||= {}
      unless h_of_sort.size > 0
        option_value_ids = variant.option_value_variants.collect(&:option_value_id).sort
        all_variants = variant.product.hash_of_option_value_ids_to_variants(true, [:option_values, user:[:role_users, { store: :payment_methods }] ] )[option_value_ids] || []

        all_variants.each do|v|
          if v.user&.store
            v.user.store.payment_methods.each do|payment_method|
              existing_v = h_of_sort[payment_method]
              if existing_v.nil? || v.send(sort_order.to_sym) > existing_v.send(sort_order.to_sym)
                h_of_sort[payment_method] = v
              end
            end
          end
        end
        @payment_method_for_variant[sort_order] = h_of_sort
      end
      h_of_sort
    end

    ##
    # @sort_order [String] the attribute of VariantAdoption; default 'price'; other choices: 'seller_rank'
    # @return [Hash of Spree::PaymentMethod to best Spree::VariantAdoption]
    def payment_method_for_variant_adoption(variant, sort_order = 'price')
      @payment_method_for_variant_adoption ||= {}
      h_of_sort = @payment_method_for_variant_adoption[sort_order] ||= {}
      unless h_of_sort.size > 0
        payment_method_for_variant(variant, sort_order).each_pair do|pm, v|
          h_of_sort[pm] = v
        end
        variant.variant_adoptions.includes(:default_price, user:[:role_users, store:[:payment_methods] ]).each do|ad|
          if ad.user&.store && ad.has_acceptable_adopter?
            ad.user.store.payment_methods.each do|payment_method|
              next unless payment_method.available_to_users
              existing_ad = h_of_sort[payment_method]
              if existing_ad.nil? || ad.send(sort_order.to_sym) > existing_ad.send(sort_order.to_sym)
                h_of_sort[payment_method] = ad
              end
            end
          end
        end
        @payment_method_for_variant_adoption[sort_order] = h_of_sort
      end
      h_of_sort
    end

    def continue_shopping_url
      unless @continue_shopping_url.present?
        url = cookies[ ControllerHelpers::ProductBrowser::LAST_PRODUCTS_SEARCH_URL ]
        @continue_shopping_url = url.present? ? url : "/"
      end
      @continue_shopping_url
    end

    def recent_order_of_same_products(user_id, product_ids)
      Spree::Order.complete.where('user_id=? and completed_at > ?', user_id, 30.days.ago).joins(:line_items).where("product_id IN (?)", product_ids).order('completed_at desc').first
    end

    ##
    # Sellers of the product's variant should not be able to see public reviews.
    def reviews_viewable?(product = nil)
      product ||= @product
      return false if product.nil?
      spree_current_user.nil? || spree_current_user&.admin? || product.variants_including_master.collect(&:user_id).exclude?(spree_current_user&.id)
    end

    ##
    # @product [Spree::Product or Elasticsearch::Model::Response::Result]
    # @exclusive_option_types [Spree::OptionType/id or Array of Spree::OptionType/id]
    def option_values_for(product, exclusive_option_types = nil)
      option_values = []
      exclusive_option_type_ids = nil
      if exclusive_option_types
        exclusive_option_type_ids = []
        if exclusive_option_types.is_a?(Spree::OptionType)
          exclusive_option_type_ids = [exclusive_option_types.id]
        elsif exclusive_option_types.is_a?(Integer)
          exclusive_option_type_ids = [exclusive_option_types]
        elsif exclusive_option_types.is_a?(Array) || exclusive_option_types.is_a?(ActiveRecord::Relation)
          exclusive_option_types.each do|el|
            if el.is_a?(Spree::OptionType)
              exclusive_option_type_ids << el.id
            elsif el.is_a?(Integer)
              exclusive_option_type_ids << el
            end
          end
        end
      end

      option_value_ids_for(product).each do|option_value_id|
        if (ov = option_values_cache_map[option_value_id] )
          option_values << ov if exclusive_option_type_ids.blank? || exclusive_option_type_ids.include?(ov.option_type_id)
        end
      end
      option_values
    end

    ##
    # @product [Spree::Product or Elasticsearch::Model::Response::Result]
    def option_value_ids_for(product)
      if product.is_a?(Elasticsearch::Model::Response::Result)
        product.as_json['_source'].try(:[], 'option_value_ids') || []
      elsif product.is_a?(Spree::Product)
        product.as_indexed_json[:option_value_ids]
      else
        []
      end
    end

    ##
    # @@option_values_cache_map [Integer => Spree::OptionValue]
    def option_values_cache_map(products = @products)
      unless @option_values_cache_map
        @option_values_cache_map = {}
        all_option_value_ids = Set.new

        if products.respond_to?(:map_with_hit)
          products.map_with_hit do |p, hit|
            option_value_ids_for(hit).to_a.each do|option_value_id|
              all_option_value_ids << option_value_id
            end
          end
        else
          products.each do|p|
            option_value_ids_for(p).to_a.each do|option_value_id|
              all_option_value_ids << option_value_id
            end
          end
        end
        Spree::OptionValue.where(id: all_option_value_ids).each do|ov|
          @option_values_cache_map[ov.id] = ov
        end
      end
      @option_values_cache_map
    end

    def count_in_cart(product)
      Spree::LineItem.joins(:product, :order).where(product_id: product.id).where("#{Spree::Order.table_name}.state='cart'").count('DISTINCT(order_id)')
    end

    ###########################
    # Cache overrides

    ## The attributes to apply filter conditions should be w/in product ES attributes.
    PERMITTED_FILTER_PARAMS = [:keywords, :query, :q, :script_score_source, :text_fields, :user_id, :taxon_ids, :option_type_ids, :option_value_ids, :sort, :sort_by, :filter, :per_page, :page]

    ##
    # More straightforward cache of results
    # @return [Hash of normalized keys]
    def cache_key_from_filters(additional_cache_key = nil)
      filter_params = params.slice(PERMITTED_FILTER_PARAMS)
      filter_params[:taxon_id] = @taxon&.id
      filter_params[:additional_cache_key] = additional_cache_key
      filter_params
    end

    def simpler_cache_key_for_products(products = @products, additional_cache_key = nil)
      time_to_cache = Date.today.to_s(:number) + '/cdn'
      filter_params = params.slice(PERMITTED_FILTER_PARAMS)
      products_cache_keys = ["search/products/#{params[:q] || params[:query]}/"]
      PERMITTED_FILTER_PARAMS.each do|pname|
        products_cache_keys << "#{pname}=#{params[pname]}"
      end
      products_cache_keys << "permalink=#{@taxon&.permalink}"
      products_cache_keys << "#{params[:page]}"
      (common_product_cache_keys + products_cache_keys + [additional_cache_key]).compact.join('/')
    end

  end
end
