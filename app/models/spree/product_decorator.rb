module Spree::ProductDecorator

  def self.prepended(base)
    base.extend ClassMethods
    base.include ::Spree::UserRelatedScopes
    base.include ::Spree::Product::ExtendedScopes
    base.include ::Spree::Product::Actions
    base.include ::Spree::Product::Cleaner
    base.include ::Spree::Product::Importer
    base.include ::Spree::Product::PhantomGenerator

    base.include ::Searchable
    base.include ::Spree::ProductSearchable

    base.whitelisted_ransackable_attributes = %w[description name slug discontinue_on user_id master variants variants_including_master retail_site_id view_count transaction_count last_adopted_at]
    base.whitelisted_ransackable_associations += %w[line_items]

    base.attr_accessor :uploaded_images, :skip_export, :variant_price, :skip_after_more_updates

    base.const_set 'ALLOW_TO_CHANGE_OPTION_TYPES_AFTER', false

  end

  module ClassMethods
    def accessible_by(ability, action)
      if ability.public_action?(action)
        self.where(nil)
      else
        self.where('user_id=?', ability.user.id)
      end
    end

    def adopted_by(user_id = nil)
      user_ids = user_id ? (user_id.is_a?(Array) ? user_id : [user_id]) : nil
      user_where_cond = user_ids ? "#{Spree::VariantAdoption.table_name}.user_id IN (#{user_ids.join(', ')})" : nil
      self.joins(:variants_including_master => :variant_adoption).where("#{Spree::VariantAdoption.table_name}.deleted_at IS NULL").where(user_where_cond)
    end
  end

  IS_ADMIN_A_SELLER = true unless defined?(IS_ADMIN_A_SELLER)

  ######################################
  # Overrides

  ##
  # Use of cache instead
  def tax_category
    @tax_category ||= super || Spree::TaxCategory.default
  end

  def run_touch_callbacks
    # touch w/ updated_at update meaningless
  end

  def touch_taxons
    # skip the useless category update calls
  end

  def brand
    brands.first&.presentation
  end

  # @return [Array of OptionValue]
  def brands
    unless @brands
      brand = Spree::OptionType.brand
      @brands = []
      variants_including_master_without_order.joins(:option_values).includes(:option_values).
      where("option_type_id=#{brand.id}").all.each do|v|
        v.option_values.each{|ov| @brands << ov if ov.option_type_id == brand.id }
      end
    end
    @brands
  end

  ######################################
  # Instance methods

  def owned_by_anyone?
    user_id && user_id != Spree::User.fetch_admin.id
  end

  alias_method :owned_by_user?, :owned_by_anyone?

  def calculate_transaction_count(only_recent = false)
    only_recent ? recent_completed_orders.count : completed_orders.count
  end

  SLUG_REGEXP = /(\S+\-)?(\d+)\Z/ unless defined?(SLUG_REGEXP)

  ##
  # Using the product words in front and replace w/ rep_variant_id
  def rep_variant_slug
    m = slug.match(SLUG_REGEXP)
    m && m[2] ? slug.gsub(m[2], (rep_variant_id || master.id).to_s ) : (rep_variant_id || master.id).to_s
  end

  ##
  # Get display_variant_adoption or create one phantom one.
  # Since exact variant the adoption is based on doesn't matter, the default would be master.
  # @base_variant [Spree::Variant] if not specified, would be master
  def rep_variant_adoption(base_variant = nil)
    base_variant ||= master
    va = display_variant_adoption || base_variant&.select_rep_variant_adoption
    va ||= base_variant.create_phantom_variation_adoption!
    if va.code != display_variant_adoption_code
      self.update_columns(rep_variant_id: va.variant_id, display_variant_adoption_code: va.code)
      self.display_variant_adoption_code = va.code
    end
    va
  end

  def display_variant_adoption_slug
    m = slug.match(SLUG_REGEXP)
    id_s = rep_variant_adoption.code.to_s
    m && m[2] ? slug.gsub(m[2], id_s) : id_s
  end

  # the master variant is not a member of the variants array
  def has_variants?
    variants_without_order.any?
  end

  def default_variant_cache_key
    "spree/default-variant-owned/#{cache_key_with_version}/#{Spree::Config[:track_inventory_levels]}"
  end

  def default_variant
    v = best_variant_id ? self.best_variant : nil

    if Rails.env.production? || Rails.env.staging?
      v ||= Rails.cache.fetch(default_variant_cache_key) do
        compute_default_variant
      end
    else
      v ||= compute_default_variant
    end

    v
  end

  def compute_default_variant
    if Spree::Config[:track_inventory_levels] && variants_without_order.in_stock_or_backorderable.any?
      variants_without_order.in_stock_or_backorderable.first
    else
      variants_without_order.first || master
    end
  end

  ##
  # Order of records is completed_at desc.
  def completed_orders(exclude_unreal_buyers = true)
    q = Spree::Order.complete.with_product_id(self.id)
    q = q.not_by_unreal_users if exclude_unreal_buyers
    q.includes(:line_items).order('completed_at desc')
  end
  alias_method :transactions, :completed_orders

  def recent_completed_orders(exclude_unreal_buyers = true)
    completed_orders.where('completed_at > ?', 4.months.ago)
  end
  alias_method :recent_transactions, :recent_completed_orders

  # @return [Spree::Order]
  def last_completed_order
    @last_completed_order ||= completed_orders.first
  end
  alias_method :last_transaction, :last_completed_order

  # @return [Spree::LineItem]
  def last_ordered_line_item
    o = last_completed_order
    o ? o.line_item_of_product(id) : nil
  end

  ##
  # Via @last_completed_order, get product's LineItem, and get its
  # Spree::VariantAdoption || Spree::Variant
  def last_ordered_record
    unless @last_ordered_record
      line_item = last_ordered_line_item
      @last_ordered_record = line_item&.variant_adoption_id ?
        (line_item&.variant_adoption || line_item&.variant) : line_item&.variant
    end
    @last_ordered_record
  end

  ##
  # @return [any of these, in this priority order: Spree::VariantAdoption, Spree::Variant, Spree::Product]
  def best_price_record(use_last_order_price = false)
    r = best_variant&.preferred_variant_adoption || best_variant || self
  end

  ##
  # Beyond simple product's variants, added user_ids from variant_adoptions also.
  def seller_ids
    # variants_including_master causes conflict in order, and .unscoped rids off product_id= also
    vars = Spree::Variant.where(product_id: self.id).select('id, deleted_at, user_id').distinct(:user_id).all
    uids = vars.collect(&:user_id)
    uids += Spree::VariantAdoption.where(variant_id: vars.collect(&:id)).select('DISTINCT(user_id)').collect(&:user_id)
    uids.uniq
  end

  def adopter_user_ids
    all_adoptions.collect(&:user_id).uniq
  end

  # @query_select_columns [String] if not set w/ 'all', only select minimal columns to minimize data fetched.
  # @return [Array of either Spree::Variant or Spree::VariantAdoption]
  def all_adoptions(must_be_viable_seller = true, query_select_columns = nil)
    t = Spree::VariantAdoption.table_name
    common_cols = (query_select_columns == 'all') ? '*' : %w(id user_id deleted_at created_at).collect{|n| "#{t}.#{n}"}.join(',')
    var_common_cols = (query_select_columns == 'all') ? '*' : %w(id user_id deleted_at created_at).collect{|n| "#{Spree::Variant.table_name}.#{n}"}.join(',')

    variants_q = Spree::Variant.adopted.where(product_id: id)
    variants_q = variants_q.by_viable_sellers if must_be_viable_seller
    adopted = variants_q.select(var_common_cols).to_a
    if must_be_viable_seller
      adopted += viable_adoptions(query_select_columns)
    else
      adopted += Spree::VariantAdoption.where(variant_id: variants_q.all.collect(&:id)).select(common_cols).to_a
    end
    adopted
  end

  ##
  # User conditions using by_viable_sellers, without variants.
  # @query_select_columns [String] if not set w/ 'all', only select minimal columns to minimize data fetched.
  # @return [Array of either Spree::Variant or Spree::VariantAdoption]
  def viable_adoptions(query_select_columns = nil)
    t = Spree::VariantAdoption.table_name
    common_cols = (query_select_columns == 'all') ? '*' : %w(id user_id deleted_at created_at).collect{|n| "#{t}.#{n}"}.join(',')
    vars = Spree::Variant.where(product_id: id).select('id, deleted_at')
    adopted = Spree::VariantAdoption.where(variant_id: vars.collect(&:id)).to_a
    adopted
  end

  def adoptions_of_user(user_id)
    vars = Spree::Variant.where(product_id: id).select('id, deleted_at')
    Spree::VariantAdoption.where(user_id: user_id, variant_id: vars.collect(&:id))
  end

  # @return [Spree::Product]
  def master_product
    master_product_id ? self.class.with_deleted.where(id: master_product_id).first : nil
  end

  # @return <nested Array of Array of Spree::Taxon> except 'Categories' root taxon.
  def categories
    unless @categories
      @categories = self.taxons.under_categories.collect do |taxon|
        taxon.categories_in_path
      end
    end
    @categories
  end

  ##
  # @_user_id [Integer] avoiding self.user_id
  # @options being passed onto ProductOptionsMap initializer.
  def options_map(_user_id, options = {})
    @option_map_by_user_id ||= {}
    options_map = @option_map_by_user_id[_user_id]
    unless options_map
      options_map = Spree::ProductOptionsMap.new(self, _user_id, nil, options)
      @option_map_by_user_id[_user_id] = options_map
    end
    options_map
  end

  ##
  # From Spree::ProductsHelper
  def option_types_presenter(variants = nil)
    variants ||= variants_including_master_without_order.includes(:option_values).where(converted_to_variant_adoption: false).spree_base_scopes
    option_types = Spree::Variants::OptionTypesFinder.new(variant_ids: variants.map(&:id)).execute
    Spree::Variants::OptionTypesPresenter.new(option_types, variants, self)
    # presenter.options.collect{|o| o[:option_values].collect{|h| h[:variant_id] } }.flatten.uniq
  end

  ##
  # Based on Spree::Variants::OptionTypesPresenter, collects the
  # variants that can be purchased via cart form's option type values.
  def presented_variant_ids
    options.collect{|o| o[:option_values].collect{|h| h[:variant_id] } }.flatten.uniq
  end

  ##
  # @product_h [Hash] the JSON hash that contains 'categories' value as list of site category attributes.
  # @return [Spree::Taxon] could be nil
  def set_category_taxon(product_h)
    mapped = nil
    if (category_names = product_h['categories'].to_a.collect{|cattr| cattr['name'] }.compact ).size > 0
      site_categories = ::Retail::SiteCategory.find_or_create_this_category_path(category_names, retail_site_id)
      site_categories.each do|site_category|
        if site_category && (mapped = site_category.deepest_mapped_taxon)
          self.classifications.find_or_create_by(taxon_id: mapped.id)
        end
      end
    end
    mapped
  end

  def days_available
    available_on ? ((Time.zone.now - available_on) / 1.day.to_f).round.to_i : 0
  end

  alias_method :days_listed, :days_available

  alias_attribute :gross_merchandise_sales, :gms
  alias_attribute :txn_count, :transaction_count

  ##
  # Instead of self.sku, this would check if there's master product for its sku.
  def master_sku
    master_product_id ? master_product.try(:sku) : sku
  end

  def is_variant_of_master
    !master_product_id.nil?
  end

  def siblings_including_self
    self.class.where(master_product_id: master_product_id)
  end

  def description_in_text
    return '' if description.blank?
    Nokogiri::HTML(description.gsub(/(<script[^>]*>.*<\/script>)/, '') ).text
  end

  ##
  # @return <Hash of Integer(:option_type_id) => Array of Spree::OptionValue, where each contains a set of variant_ids>
  def hash_of_option_type_ids_and_values(include_master = false, only_searchable_option_types = false)
    unless @hash_of_option_type_ids_and_values
      option_value_id_to_variant_ids = ActiveSupport::HashWithIndifferentAccess.new
      the_association = include_master ? variants_including_master_without_order : variants_without_order
      the_association.includes(:option_value_variants).each do |v|
        v.option_value_variants.each do |ovv|
          option_value_id_to_variant_ids.add_into_list_of_values(ovv.option_value_id, v.id)
        end
      end
      option_type_conds =  { id: option_value_id_to_variant_ids.keys }
      option_type_conds[ ::Spree::OptionType.table_name ] = { searchable_text: true } if only_searchable_option_types
      own_option_values = ::Spree::OptionValue.includes(:option_type).where(option_type_conds).
          order("#{::Spree::OptionValue.table_name}.position ASC").all
      own_option_values.each do |ov|
        ov.variant_ids = option_value_id_to_variant_ids[ov.id]
      end
      @hash_of_option_type_ids_and_values = own_option_values.group_by(&:option_type_id)
    end
    @hash_of_option_type_ids_and_values
  end

  # @return [Hash of sorted Array of Spree::OptionValue#id => Array of Spree::Variant ]
  def hash_of_option_value_ids_to_variants(include_master = true, relationship_includes = [:user, :option_values])
    query = include_master ? variants_including_master_without_order : variants_without_order
    h = {}
    query.includes(*relationship_includes).each do|v|
      k = v.option_values.collect(&:id).sort
      h[k] ||= []
      h[k] << v
    end
    h
  end

  ##
  # Find 1st variant's option values include that combo of option types and values.
  # @query [ActiveRecord::Relation or Spree::Product::ActiveRecord_Relation]
  # @option_type_to_values [ Integer or Spree::OptionType => single or Array of presentation value from Spree::OptionValue ]
  def find_variant_with_option_values(query = nil, option_type_to_values = {})
    query ||= variants_including_master_without_order.with_deleted
    query.find do |v|
      type_match_count = 0
      option_type_to_values.each_pair do |ot, ovs|
        next if ovs.blank?
        ot_id = ot.is_a?(Spree::OptionType) ? ot.id : ot
        list = ovs.is_a?(Array) ? ovs : [ovs]
        value_match_count = 0
        list.each do |ov_to_match|
          value_match_count += 1 if v.option_values.any? do |ov|
            ov.option_type_id == ot_id && ov.presentation.downcase == ov_to_match.downcase
          end
        end
        type_match_count += 1 if (list.size == value_match_count)
      end
      type_match_count == option_type_to_values.size
    end
  end

  ##
  # @return [String] can be public, pending, invalid, waiting
  def status
    if status_code && status_code > Spree::RecordReview::MAX_ACCEPTABLE_STATUS_CODE
      'invalid'
    elsif price.to_f <= 0.0 || variant_images.count == 0
      'pending'
    elsif indexable?
      last_review_at ? 'public' : 'not reviewed'
    else
      'pending'
    end
  end

  def median_price(currency = nil, favorable_payment_method_id = nil)
    currency ||= self&.user&.store&.default_currency || Spree::Config[:currency]
    variants_query = self.variants_including_master_without_order.includes(:default_price) # all variants
    query = if favorable_payment_method_id
        variants_query.joins(user:{ store: :store_payment_methods }).where("spree_store_payment_methods.payment_method_id=#{favorable_payment_method_id}")
      else
        variants_query
      end
    prices = [] # exclude nil amounts
    query.each{|v| price = v.price_in(currency); prices << price if price&.amount }
    #logger.debug "| got payment_method prices: #{prices.collect(&:amount)}" if favorable_payment_method_id && prices.size > 0
    if prices.empty? && favorable_payment_method_id # none in that payment method; just go all
      variants_query.each{|v| price = v.price_in(currency); prices << price if price&.amount }
    end
    prices = prices.uniq(&:amount).sort_by(&:amount)
    #logger.debug "| prices (#{prices.size}): #{prices.collect(&:amount)}"
    if prices.size < 2
      master.price_in(currency)
    elsif prices.size % 2 == 0
      first_median_index = prices.size / 2 - 1
      first_median = prices[first_median_index]
      Spree::Price.new(variant_id: first_median.variant_id,
        currency: first_median.currency,
        amount: (first_median.amount + prices[first_median_index + 1].amount ) / 2.0 )
    else
      prices[prices.size / 2]
    end
  end

  ##
  # Dynamic check on which user, owner or adopter, to show what price
  def display_price_for(user)
    if user.id == self.id || user.admin?
      self.display_price
    else
      va = variant_adoption_for(user)
      va&.display_price || self.display_price
    end
  end

  ##
  # Latest adoption.
  # @return [Spree::VariantAdoption or nil]
  def variant_adoption_for(user)
    va = nil
    self.variants_including_master_without_order.all.each.find do|v|
      cur_va = v.variant_adoptions.by_this_user(user.id).includes(:prices)&.last
      va = cur_va if cur_va && (va.nil? || va.created_at < cur_va.created_at)
    end
    va
  end

  def next_taxon_price
    @next_taxon_price ||= self.taxons.first&.next_taxon_price
  end

  # If product's 1st taxon has TaxonPrice, would compare @price to their range of amounts.
  def is_price_within_range?(price, currency = nil)
    if (t = self.taxons.first)
      t.try(:is_price_within_range?, price, currency)
    else
      true
    end
  end
end

::Spree::Product.prepend Spree::ProductDecorator if ::Spree::Product.included_modules.exclude?(Spree::ProductDecorator)
