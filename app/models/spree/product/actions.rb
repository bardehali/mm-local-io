module Spree::Product::Actions
  extend ActiveSupport::Concern

  require 'open-uri'

  included do
    INITIAL_CURATION_SCORE = 0
    DEFAULT_IQS = 20
    DEFAULT_BLANK_IQS = 0
    TEST_IQS = 5
    SINGLE_IMAGE_IQS = 15
    ADMIN_CREATED_IQS = 50
    SET_AVAILABLE_ON_INITIALLY = false
    GENERATE_PHANTOM_VARIANT_ADOPTIONS_FOR_ALL = true

    before_save :normalize_attributes
    after_create :reset_slug!
    after_save :after_save_updates!

    validates_presence_of :taxon_ids, message: I18n.t('errors.product.category_required')
  end



  ####################

  # operations of data to create other product or properties move to Importer

  ##
  # Some IQS that should stay same throughout.
  # If user test or not, would give some TEST_IQS.
  # @return [nil or Integer]
  def overriding_iqs
    return nil if user_id.nil? || user.nil?
    if user
      if ( user.quarantined? )
        return 0
      elsif ( user&.admin? || user&.test_or_fake_user_except_phantom? )
        return TEST_IQS
      end
    end
    nil
  end

  ##
  # Reviews the number of images and given curation_score, and
  # use the minimum of those for iqs.  This would also re-determine
  # the delete status of the product based on iqs.
  def build_auto_set_attributes
    cnt = variant_images.count
    iqs_target = overriding_iqs
    iqs_target ||= (iqs_target == TEST_IQS || iqs.to_i >= DEFAULT_IQS) ? iqs : nil
    if price.to_f <= 0.0 || cnt == 0
      # self.discard
      { images_count: cnt, iqs: 0 }
    elsif cnt == 1
      { images_count: cnt, iqs: iqs_target || SINGLE_IMAGE_IQS, deleted_at: nil }
    else
      { images_count: cnt, iqs: iqs_target || DEFAULT_IQS, deleted_at: nil }
    end
  end

  ##
  # Clears away errors first.  And validate adoption related attributes.
  def validate_for_list_variants
    errors.clear
    if variant_price.to_f <= 0.0
      errors.add(:variant_price, :invalid, message: I18n.t('errors.product.variant_price_invalid') )
    end
    required_option_types = self.option_types.find_all(&:required_to_specify_value?)
    # some times crappy variants don't have any option values while required_option_types
    # exclude master
    has_valid_variant = variants.find{|v| v.option_value_variants.count >= required_option_types.size }
    logger.debug "| required_option_values: #{required_option_types.collect(&:name) }"
    logger.debug "| product.user_variant_option_value_ids: #{self.user_variant_option_value_ids}"
    if required_option_types.size > 0 && (has_valid_variant && user_variant_option_value_ids.blank? )
      msg = required_option_types.find(&:size?) ? I18n.t('spree.errors.product.select_the_sizes_you_provide') :
        I18n.t('spree.errors.product.select_the_options_you_provide')
      errors.add(:option_types, :invalid, message: msg )
    end
  end

  # Based on values from build_auto_set_attributes, update itself which also includes images_count.
  # The condition to run is not product is not reviewed.
  def recalculate_status!
    if last_review_at.nil?
      self.update_columns( build_auto_set_attributes.merge(updated_at: Time.now) )
      self.reindex_document
    end
  end

  ##
  # Different from recalculate_status! because this has conditions to recalculate, ADMIN_CREATED_IQS.
  # This should be used by auto calls like image changes.
  def auto_recalculate_status!
    if iqs.to_i < ADMIN_CREATED_IQS && iqs != TEST_IQS
      recalculate_status!
    end
  end

  def should_generate_new_friendly_id?
    @check_slug || name_changed? || super
  end

  ##
  # Override of Slugged module.
  def set_slug(normalized_slug = nil)
    if should_generate_new_friendly_id? && name.present?
      self.slug = name.gsub(/([^a-z0-9\-]+)/i, '-' ).gsub(/(\A\-+|\-+\Z)/,'').downcase
      self.slug << '-' + ( id ? id.to_s : "t#{Time.now.to_i % 100000000}" )
    end
  end

  ##
  # Mainly after_create, enforce to recall set_slug and save slug updated.
  def reset_slug!
    if id
      @check_slug = true
      set_slug
      self.update_column(:slug, slug) # skip after calls
    end
  end

  ##
  # @_uploaded_images [Array of parameter hash w/ Spree::Asset properties]
  def process_uploaded_images(_uploaded_images = nil)
    # logger.debug "-------------------------> \nsave_uploaded_images: #{_uploaded_images || uploaded_images}"
    (_uploaded_images || uploaded_images).to_a.each do|image_h|
      begin
        uploaded_at = image_h[:attachment]
        image_h[:viewable_type] ||= 'Spree::Variant'
        image_h[:viewable_id] ||= self.master.id

        image_asset = nil
        if image_h[:id]
          image_asset = Spree::Image.where(id: image_h[:id] ).first
          image_asset.attributes = image_h

        else
          image_asset = Spree::Image.new(image_h)
          image_asset.preset_attributes
        end
        image_asset.decode_base64_image
        image_asset.save
        # logger.debug "    #{image_h}\n    valid? #{image_asset.valid?}: #{image_asset.errors.full_messages}"
      rescue IOError => ioe
        logger.warn "** Problem processing uploaded image #{image_h}:\n#{ioe}"
      end
    end
  end



  HTML_MARKS_REGEXP = /(&[a-z]{2,5};)|href=["']([^"']+)["']|<script[^>]*>(.+)<\/script>/
  HTML_TAGS_AS_WHOLE_REGEXP = /(<(script|style)\b[^>]*>.+<\/(script|style)>)/i
  HTML_TAGS_REGEXP = /(<\/?\w[^>]*\/?>)/i
  HTML_TAGS_TO_KEEP_REGEXP = /\A<img|media|video/i

  def normalize_attributes
    self.name.gsub!(HTML_MARKS_REGEXP, '')
    self.name.gsub!(/\A([\W]+)/i, '')
    self.name.strip!
    if description
      self.description.gsub!(HTML_TAGS_AS_WHOLE_REGEXP, ' ')
      self.description.gsub!(HTML_TAGS_REGEXP, ' ')
      description.scan(HTML_TAGS_REGEXP).each do|found_tags|
        self.description.gsub!(found_tags.first, ' ') unless found_tags.first =~ HTML_TAGS_TO_KEEP_REGEXP
      end
      self.description = description.compact
    end
    self.available_on ||= Time.now if SET_AVAILABLE_ON_INITIALLY && !deleted? # not deleted, should be activated
    self.iqs ||= overriding_iqs || DEFAULT_BLANK_IQS
  end

  def set_update_attributes
    self.has_sorting_rank_changes = (transaction_count_changed? || gms_changed?)
  end

  def update_variants!(force_to_update = false, &block)
    if force_to_update || has_sorting_rank_changes
      self.variants_including_master.each do|v|
        yield v if block_given?
        v.update_sorting_rank!
      end
    end
  end


  ##
  # Join values into one value within DB limit.
  def set_property_with_list(spec_name, spec_list)
    return if spec_name.blank? || spec_list.blank?
    value_s = build_property_value(spec_list)
    self.set_property(spec_name, value_s) if value_s.present?
  end

  # DB column limit of 100, need to join manually
  def build_property_value(spec_list)
    value_s = ''
    spec_list.uniq.each do|spec|
      if value_s.size + spec.value_1.to_s.size + 1 < 100
        value_s << ' ' unless value_s == ''
        value_s << spec.value_1.to_s
      else
        break
      end
    end
    value_s
  end

  # From Spree::ProductDuplicator
  def reset_properties
    self.product_properties.map do |prop|
      prop.dup.tap do |new_prop|
        new_prop.created_at = nil
        new_prop.updated_at = nil
      end
    end
  end

  def recalculate_view_count!
    total_count = self.variants_including_master.select('id,view_count').collect(&:view_count).sum
    self.update(view_count: total_count) if total_count != view_count
    total_count
  end

  def recalculate_gms!

  end
  alias_method :recalculate_gross_merchandise_sales!, :recalculate_gms!


  TEXT_BREAKABLE_REGEXP = /[\-\s,:]+/
  ATTRIBUTES_TO_STRIP = [:name]

  # This only generates the list of matching OptionValue, not applying to product's variants like @collect_option_values_from!.
  # @param option_types <Collection of Spree::OptionType> default list from Spree::OptionType.collectible_option_types
  # @param attributes <Collection of Symbol> search in which attributes of the product; default :name
  # @return <Collection of Spree::OptionValue>
  def collect_option_values_from(option_types = nil, attributes = nil)
    attributes ||= ATTRIBUTES_TO_STRIP
    option_types ||= ::Spree::OptionType.collectible_option_types

    #words = attributes.collect {|a| self.send(a).word_combos }.flatten.uniq
    #::Spree::OptionValue.where(option_type_id: option_types.collect(&:id), user_id: nil, name: words).all

    # moved to use ElasticSearch index
    context = attributes.collect{|a| self.send(a) }.join(' ')
    search = ::Spree::OptionValue.search_for_matches( context, option_types )
    search.respond_to?(:records) ? search.records : search.result
  end

  ##
  # Beyond collecting option values from @collect_option_values_from, create entries to variants if needed.
  # @param option_types <Collection of Spree::OptionType> pass to collect_option_values_from
  # @param attributes <Collection of Symbol> pass to collect_option_values_from
  # @options
  #   :create_option_value_variants_for - either ('all' or else 'only_master')
  # @return <Collection of Spree::OptionValue>
  def collect_option_values_from!(option_types = nil, attributes = nil, options = {} )
    entries_only_for_master = options[:create_option_value_variants_for] != 'all'
    existing_ov_ids_map = {}
    vars = id && !entries_only_for_master ? variants_including_master.includes(:option_value_variants)
      : [find_or_build_master]
    vars.each do|v|
      v_ov_ids = v.option_value_variants.collect(&:option_value_id)
      existing_ov_ids_map[v.id] = v_ov_ids
    end
    collected_ovs = collect_option_values_from(option_types, attributes)
    # collected_ov_ids = collected_ovs.collect(&:id)
    # create entries of ProductOptionType if needed.
    (collected_ovs.collect(&:option_type_id) - product_option_types.collect(&:option_type_id) ).uniq.each do|ot_id|
      if id
        self.product_option_types.find_or_create_by(option_type_id: ot_id)
      else
        self.product_option_types << ::Spree::ProductOptionType.new(option_type_id: ot_id)
      end
    end
    # Not every variant already has these OVs
    update_h = {}
    vars.each do|v|
      cur_master = find_or_build_master
      v_existing_ov_ids = existing_ov_ids_map[v.id] || []
      strip_attributes_with!(collected_ovs) do|attribute, stripped_ov|
        unless v_existing_ov_ids.include?(stripped_ov.id)
          if id
            v.option_value_variants.create(option_value_id: stripped_ov.id)
          else
            cur_master.option_value_variants << ::Spree::OptionValueVariant.new(variant_id: cur_master.id, option_value_id: stripped_ov.id )
          end
          v_existing_ov_ids << stripped_ov.id
          @check_slug = true
        end
        update_h[attribute] = self.send(attribute)
      end
    end

    if update_h.size > 0
      self.update_columns(update_h)  # skip callbacks
      self.reset_slug!
    end

    collected_ovs
  end

  ##
  # There could be some customized case when option_types and option_value_ids provided to save
  # them to the master.
  # @current_user_id [Integer] would be required if no self.current_user_id to create master's adoptions.
  def save_option_values!(params = {}, current_user_id = nil)
    # Fix up option types - Spree mysteriously miss out option type like size; there ruining variant combos.
    if option_type_ids.blank?
      taxons.includes(:option_types).each do|t|
        options_map(self.user_id).sync_option_types(t.closest_related_option_types.to_a, true)
      end
    end

    logger.debug "| save_option_values! ----------------------"
    required_option_types = self.option_types.find_all(&:required_to_specify_value?)
    logger.debug "| required_option_values: #{required_option_types.collect(&:name) }"

    if master_option_value_ids.present?
      # Replace option_type_id one by one
      ::Spree::OptionValue.where(id: master_option_value_ids).all.group_by(&:option_type_id).each_pair do|option_type_id, ovs|
        self.master.option_value_variants.joins(:option_value).
            where( Spree::OptionValue.table_name => { option_type_id: option_type_id } ).delete_all
        ovs.each{|ov| self.master.option_value_variants.create(option_value_id: ov.id) }
      end

    elsif user_variant_option_value_ids.present?
      logger.debug "| user_variant_option_value_ids #{user_variant_option_value_ids}, owned_by_any_one? #{owned_by_anyone?}"
      user_variant_option_value_ids.each_pair do|v_user_id, option_value_ids|
        if (owned_by_anyone? || v_user_id == Spree::User.fetch_admin.id) && (self.user_id == v_user_id || !Spree::Variant::USE_VARIANT_ADOPTIONS )
          options_map(v_user_id).sync_option_values(option_value_ids, user_id: v_user_id)
        else
          other_attr = { user_id: v_user_id }
          if (variant_price = params[:product].try(:[], :variant_price) )
            other_attr[:price] = variant_price
          end
          self.sync_variant_adoptions(v_user_id, option_value_ids, other_attr )
        end
      end

    elsif required_option_types.size == 0 # just adopt master
      variant_price = params[:product].try(:[], :variant_price)
      if variant_price && current_user_id
        master.create_variant_adoption_for(current_user_id || user_id, price: variant_price )
      end
    end
  end

  ##
  # Finds or create this user's VariantAdoption record w/ matching master variant's values.
  # @other_attributes
  #   :price - would replace variant's price
  def sync_variant_adoptions(user_id, option_value_ids, other_attributes = {})
    return [] if option_value_ids.blank?
    m = options_map(user_id, exclude_zero_value: false)
    logger.debug "| found master ProductOptionsMap size #{m.size} to sync_variant_adoptions"
    logger.debug "| m: #{m}"
    logger.debug "| option_value_ids #{option_value_ids}"
    logger.debug "| other_attributes #{other_attributes}"
    option_value_ids.each do|ov_ids|
      m_key = ov_ids.is_a?(Array) ? ov_ids.sort : ov_ids
      if (creators_variant = m.variant_for_option_values(m_key).try(:first) )
        creators_variant.create_variant_adoption_for(user_id, other_attributes)
      end
    end
  end

  ##
  # When the attribute (name) is stripped w/ matching option value, like brand, would yield that OptionValue
  # @modify_attributes [Boolean] default false; whether to remove word-matched to option values from attributes like name, description
  # @yield [String, name of attribute], [Spree::OptionValue]
  def strip_attributes_with!(option_values, modify_attributes = ::Spree::OptionValue::STRIP_FROM_ATTRIBUTES)
    option_values.each do|option_value|
      begin
        word_regex = /(\b#{option_value.name.split_to_title_words.join('[\W\b]+')})\b/i
        ATTRIBUTES_TO_STRIP.each do|a|
          if self.send(a)
            word_stripped = modify_attributes ? self.send(a).gsub!(word_regex, '') : self.send(a).match(word_regex).try(:[], 0)
            if word_stripped
              yield a, option_value
            end
            self.send(a).strip!
          end
        end
      rescue RegexpError => re
        logger.warn "Problem stripping_attributes: #{re.message} for #{self}"
      end
    end
  end

  # Create ::Spree::Price from .price_attributes.
  def apply_price_attributes(save_or_not = false)
    if price_attributes.present?
      ids_to_delete = []
      existing_map = master.prices.group_by(&:currency)
      price_attributes.each_with_index do |price_attr, price_idx|
        new_price = ::Spree::Price.new(price_attr)
        if new_price.amount.to_f > 0.0
          if new_price.valid?
            if (existing_one = existing_map[new_price.currency].try(:first))
              existing_one.amount = new_price.amount
              # logger.debug "| existing: #{existing_one.id} => #{existing_one}"
              existing_one.save if save_or_not
              existing_map.delete(new_price.currency) # duplicate but empty ones would delete
            else
              if new_price.has_default_currency? && self.price.to_f.zero?
                self.price ||= new_price.amount
              else
                if save_or_not
                  self.master.prices.create new_price.attributes
                else
                  self.master.prices << new_price
                end
              end
              existing_map[new_price.currency] ||= []
              existing_map[new_price.currency] << new_price
            end
          else
            self.errors.add("price_attributes[#{price_idx}]".to_sym, new_price.errors.messages.first)
          end
        else # no amount
          if (existing_one = existing_map[new_price.currency].try(:first))
            ids_to_delete << existing_one.id if existing_one.amount.to_f > 0.0 && !existing_one.changed?
          end
        end # new_price.amount
      end

      # Clear away old duplicates or removed
      if save_or_not && ids_to_delete.present?
        ::Spree::Price.where(id: ids_to_delete).delete_all
      end
    end
  end

  # ensure_images_processed! moved to Cleaner

  ####################
  # Background or after calls

  def increment_view_count!
    self.update_columns(view_count: self.view_count.to_i + 1, last_viewed_at: Time.now )
    #self.es.update_document if indexable? Is Elasticsearch updated needed here?
  end

  handle_asynchronously :increment_view_count!, queue:'VIEW_COUNTS' if Rails.env.production?

  ##
  # Group up after_save operations and schedule async.  Prevent ahead recalls of
  # after_save.
  def after_save_updates!
    return if self.skip_after_more_updates == true

    process_uploaded_images

    save_option_values!

    more_after_save_updates!
  end

  ##
  # Async call.
  def more_after_save_updates!
    return if self.skip_after_more_updates == true || self.deleted?
    if phantom?
      generate_phantom_variants!
    else
      collect_option_values_from! # no stripping like brands
    end
    vars = if GENERATE_PHANTOM_VARIANT_ADOPTIONS_FOR_ALL || phantom?
        generate_phantom_variant_adoptions!
      else
        self.variants_without_order.all
      end
    if vars.last
      self.update_columns(rep_variant_id: vars.last&.id || vars.master&.id )
    end
    unless iqs.to_i < 1 # draft or test
      generate_product_reviews!
      remove_cache!
    end
  end

  handle_asynchronously :more_after_save_updates! if Rails.env.production?

  ##
  # Those on cache server: cart_form
  def remove_cache!
    Rails.cache.delete("views/product.#{id}.cart_form")
    Rails.cache.delete("views/product.#{id}.cart_form.for_others")
    Rails.cache.delete(default_variant_cache_key)
  end

  ##
  # Pick worst seller's variant.
  def auto_select_rep_variant!
    # self.variants_including_master_without_order.each(&:reset_preferred_variant_adoption!)

    # This avoids further trigger
    new_best_variant = select_best_variant(retail_site_id.nil?) || select_lowest_price_variant || master
    new_rep_variant_adoption = rep_variant_adoption
    should_update_in_search = (display_variant_adoption_code != new_rep_variant_adoption&.code || best_variant_id != new_best_variant&.id)

    self.update_columns(
      rep_variant_id: new_rep_variant_adoption&.variant_id,
      display_variant_adoption_code: new_rep_variant_adoption&.code,
      best_variant_id: new_best_variant&.id
    )
    if should_update_in_search
      self.reindex_document
    end
  end
  handle_asynchronously :auto_select_rep_variant!, priority: 8, queue:'ITEM_REP_ADJUSTMENT', run_at: Proc.new { 30.minutes.from_now } if Rails.env.production?

  ##
  # For each variant, call its reset_preferred_variant_adoption! and set best_variant_id
  # by using auto_select_rep_variant! intentionally without delaoy.
  # Should be called when there's new variant/adoption.
  def schedule_to_update_variants!

    self.variants_without_order.includes(:variant_adoption).each do|v|
      top_ad = v.reset_preferred_variant_adoption!
    end
    if self.respond_to?(:auto_select_rep_variant_without_delay!)
      self.auto_select_rep_variant_without_delay!
    else
      self.auto_select_rep_variant!
    end
  end
  handle_asynchronously :schedule_to_update_variants!, priority: 8, queue:'AFTER_ORDER_ITEM_STATS', run_at: Proc.new { 30.minutes.from_now } if Rails.env.production?

  ##
  # @next_try_by_adoption_price [Boolean] default true; if no order to get best transacted variant,
  #   run @select_best_variant_by_adoption_price; this can be false to skip that.
  def select_best_variant(next_try_by_adoption_price = true)
    best_variant = select_best_variant_by_adoption_price_with_paypal
    best_variant = nil if best_variant&.deleted?
    best_variant
  end

  def select_best_variant_by_latest_order
    latest_order = Spree::Order.complete.not_by_unreal_users.with_product_id(self.id).includes(:line_items).order('completed_at desc').first
    latest_order&.line_item_of_product(id)&.variant
  end

  def select_best_variant_by_adoption_price
    variants_adopted = [] # exists if itself is adoption or has variant_adoptions
    self.variants_including_master_without_order.
      includes(:prices, user:[:role_users], preferred_variant_adoption:[:default_price] ).to_a.
      # reject{|v| v.seller_based_sort_rank.to_i.zero? }.
      each do|v|
        variants_adopted << v if v.user != user_id || v.preferred_variant_adoption
    end
    variants_adopted.sort do|x,y|
      (x.preferred_variant_adoption&.price || x.price).to_f <=> (y.preferred_variant_adoption&.price || y.price).to_f end.first
  end

  ##
  # Pick the adoption within recent period that has lowest Paypal price.
  def select_best_variant_by_adoption_price_with_paypal
    var_ids = self.variants.select('id, deleted_at').collect(&:id)
    var_ids = [self.master.id] if var_ids.empty? # old items may not have variants

    lowest_paypal_price = nil
    lowest_paypal_adoption = nil
    Spree::VariantAdoption.where(variant_id: var_ids ).
      includes(:default_price, user:[:role_users, store:[:store_payment_methods] ]).each do|va|
      next if va.nil? || va.user.nil? || va.price.nil? || !va.has_acceptable_adopter?
      if va.user.store&.has_paypal? && (lowest_paypal_price.nil? || va.price < lowest_paypal_price)
        lowest_paypal_price = va.price
        lowest_paypal_adoption = va
      end
    end

    if lowest_paypal_adoption.is_a?(Spree::VariantAdoption)
      unless lowest_paypal_adoption.preferred_variant # reset to this
        lowest_paypal_adoption = lowest_paypal_adoption.variant&.reset_preferred_variant_adoption!
      end
      lowest_paypal_adoption.is_a?(Spree::VariantAdoption) ? lowest_paypal_adoption.variant : lowest_paypal_adoption
    else
      lowest_paypal_adoption
    end
  end

  def select_lowest_price_variant
    self.variants_including_master_without_order.includes(:default_price).to_a.sort_by(&:price).first
  end

  def select_rep_variant
    self.variants_including_master_without_order.joins(:user).includes(:prices, user:[:role_users] ).order("seller_rank asc, #{Spree::Variant.table_name}.id DESC").first
  end

end
