module Spree::VariantDecorator

  def self.prepended(base)
    base.extend ClassMethods

    base.include ::Spree::UserRelatedScopes
    base.include ::Spree::SellerRelatedInfo
    base.include ::Spree::MoreProductsHelper
    base.include ::Spree::Product::PhantomGenerator

    base.attr_accessor :has_view_count_changed

    base.belongs_to :product, -> { with_deleted }, class_name:'Spree::Product'

    base.has_many :classifications, through: :product
    base.belongs_to :user, class_name: 'Spree::User'
    base.has_many :variant_adoptions, class_name:'Spree::VariantAdoption', dependent: :destroy
    base.has_many :adoptions, class_name:'Spree::VariantAdoption', dependent: :destroy
    base.has_one :variant_adoption, -> { with_deleted }, class_name:'Spree::VariantAdoption'

    base.has_one :preferred_variant_adoption, -> { where(preferred_variant: true) }, class_name:'Spree::VariantAdoption'

    base.delegate :transaction_count, :txn_count, :engagement_count, :gms, :days_available, :days_listed, to: :product
    base.delegate :seller_rank, :current_sign_in_at, to: :user

    #################################
    # Scopes copied from

    base.scope :indexable, -> { where('is_master=false AND user_id IS NOT NULL') }
    base.scope :original, -> { joins(:product).where("#{Spree::Variant.table_name}.user_id IS NULL OR #{Spree::Product.table_name}.user_id = #{Spree::Variant.table_name}.user_id") }
    base.scope :master, -> { original }
    base.scope :adopted, -> { joins(:product).where("is_master=false AND #{Spree::Variant.table_name}.user_id IS NOT NULL AND (#{Spree::Product.table_name}.user_id IS NULL OR #{Spree::Product.table_name}.user_id != #{Spree::Variant.table_name}.user_id)") }


    # avoid acts_as_list auto appending of "order by position" to vairants scope.
    base.scope :default_order, -> { order(id: :asc) }

    base.scope :ascend_by_updated_at, -> { order(updated_at: :asc) }
    base.scope :descend_by_updated_at, -> { order(updated_at: :desc) }
    base.scope :ascend_by_name, -> { order(name: :asc) }
    base.scope :descend_by_name, -> { order(name: :desc) }

    base.before_create :set_defaults
    base.before_update :set_update_attributes
    base.after_update :update_product

    # base.after_create :update_product_rep_variant
    base.after_destroy :update_product_rep_variant

    ###
    # Patch

    # Easier to clear all and rewrite wanted ones
    base.clear_validators!
    base.before_validation :set_cost_currency

    base.validate :check_price

    base.with_options numericality: { greater_than_or_equal_to: 0, allow_nil: true } do
      validates :cost_price
      validates :price
    end
    base.validates :sku, uniqueness: { conditions: -> { where(deleted_at: nil) }, case_sensitive: false },
                    allow_blank: true, unless: :disable_sku_validation?

    base.whitelisted_ransackable_attributes = %w[weight sku user_id variant_adoptions]

    base.const_set 'USE_VARIANT_ADOPTIONS', true
  end

  module ClassMethods
    def accessible_by(ability)
      self.where("#{Spree::Variant.table_name}.user_id=?", ability.user.id) 
    end
  end

  def to_s
    "(#{id}) user #{user_id}: #{sku_and_options_text}"
  end

  def owned_by_anyone?
    user_id && user_id != Spree::User.fetch_admin.id
  end

  alias_method :owned_by_user?, :owned_by_anyone?

  def phantom?
    self.user_id.nil? || self.user.nil? || self.user.phantom_seller? || self.product.phantom?
  end

  # @exclude_option_type_ids [nil or Array] default would exclude brand
  # yield [Spree::OptionValue] to show
  def option_values_for_display(limit = nil, exclude_one_value = true, exclude_option_type_ids = nil)
    _option_values = []
    exclude_option_type_ids ||= [Spree::OptionType.brand.id]
    # logger.debug "| exclude_option_type_ids #{exclude_option_type_ids}"
    option_values.sort_by(&:option_type_position).each do|ov| 
      next if exclude_one_value && ov.one_value?
      next if exclude_option_type_ids.present? && exclude_option_type_ids.include?(ov.option_type_id)
      break if limit && _option_values.size >= limit
      yield ov if block_given?
      _option_values << "#{ov.option_type.presentation}: #{ov.presentation}"
    end
    _option_values
  end

  ##
  # Possible blank text when no option values
  # @limit [Integer] how many option values to show
  def sku_and_options_text(limit = nil, exclude_option_type_ids = [])
    s = option_values_for_display(limit, nil, exclude_option_type_ids).join(', ')
    if s.blank? && price
      s = 'Price: $%.2f' % [price]
    end
    if s.blank?
      s = 'Created at %s' % created_at.try(:to_s, :long)
    end
    s
  end



  ###########################################
  # Overrides

  def create_stock_items
  end

  def set_master_out_of_stock
  end


  ###########################################
  # Outside update calls

  ##
  # @sorting_rank deprecated because different sellers participating to a variant 
  # has moved to VariantAdoption.
  def update_sorting_rank!
    return self.sorting_rank if phantom? 
    self.sorting_rank = sprintf('%09d,%010.2f', self.transaction_count * 0.5 * product.view_count, 1000000 - self.price.to_f)
    self.save
    self.sorting_rank
  end

  ##
  # Re-query for preferred_variant attribute in Spree::VariantAdoption
  def reset_preferred_variant_adoption!
    return nil if variant_adoptions.blank?
    pm_to_variant_adoption_map = payment_method_for_variant_adoption(self, 'seller_based_sort_rank')
    top_pm = pm_to_variant_adoption_map.keys.sort_by(&:position)[0]
    top_ad = pm_to_variant_adoption_map[top_pm]
    if top_ad.nil? || (new_record? && top_ad.user&.phantom_seller? ) # phantom still not good enough
      if (phantom_seller = top_ad&.user&.phantom_seller? ? top_ad.user : Spree::User.pick_phantom_sellers(1).first )
        taxon_price = product.next_taxon_price
        new_price = taxon_price&.price || product.price
        top_ad = create_variant_adoption_for(phantom_seller.id, { price: new_price })
      end
    end
    if top_ad.is_a?(Spree::VariantAdoption)
      if preferred_variant_adoption && top_ad.id != preferred_variant_adoption.id
        preferred_variant_adoption.update_columns(preferred_variant: false)
      end
      top_ad.update(preferred_variant: true)
    else # if top_ad.nil? || top_ad.is_a?(Spree::Variant)
      variant_adoptions.update_all(preferred_variant: false)
    end
    top_ad
  end

  def move_to_another_variant!(base_variant)
    raise ArgumentError.new("base_variant has different product than this") if self.product_id != base_variant.product_id
    # associated records: images, inventory_units, line_items, stock_items, variant_adoptions
    # except option_value_variants
    self.images.update_all(viewable_id: base_variant.id)
    self.inventory_units.update_all(variant_id: base_variant.id)
    self.variant_adoptions.update_all(variant_id: base_variant.id)
    Spree::LineItem.where(product_id: self.product_id, variant_id: self.id).update_all(variant_id: base_variant.id)
    self.stock_items.update_all(variant_id: base_variant.id)
    if !self.converted_to_variant_adoption && base_variant.converted_to_variant_adoption
      base_variant.update_columns(converted_to_variant_adoption: false)
    end
  end

  def convert_into_variant_adoption!(other_attributes = {})
    matching_var_adopt = self.variant_adoptions.find_by(user_id: user_id)
    unless matching_var_adopt
      prices = self.prices.nil? ? [] : self.prices.collect{|price| 
        Spree::AdoptionPrice.new(amount: price.amount, currency: price.currency, 
          country_iso: price.country_iso, compare_at_amount: price.compare_at_amount) }
      matching_var_adopt = Spree::VariantAdoption.create(
        other_attributes.merge(user_id: user_id, variant_id: id, prices: prices) )
    end
    matching_var_adopt
  end

  ##
  # First convert_into_variant_adoption!, and then set user_id w/ phantom
  def replace_with_phantom_and_move_to_variant_adoption!(phantom_seller = nil)
    matching_var_adopt = convert_into_variant_adoption!(created_at: created_at)
    phantom_seller ||= pick_phantom_sellers([], 1).first
    self.update_columns(user_id: phantom_seller.id)
    ::Spree::LineItem.where('variant_id=? AND variant_adoption_id IS NULL', id).update_all(variant_adoption_id: matching_var_adopt.id)
    matching_var_adopt
  end

  # @return [Spree::VariantAdoption]
  def create_variant_adoption_for(user_id, other_attributes = {})
    Spree::VariantAdoption.transaction do
      ad = self.variant_adoptions.find_or_create_by(user_id: user_id)
      ad.attributes.merge!(other_attributes) if other_attributes.size > 0
      ad.price = other_attributes[:price] if other_attributes[:price].to_f > 0

      self.prices.each do|price| 
        ad.prices.find_or_create_by(price.attributes.slice('currency', 'country_iso') ) do|_price|
          _price.price ||= other_attributes[:price] || price.amount
          _price.compare_at_amount = price.compare_at_amount
        end
      end
      # logger.debug "* ad #{ad.attributes}, prices #{ad.prices.collect(&:amount) }"
      ad.save
      ad
    end
  end


  ##
  # The setup of Spree::Variant is complicated for destroying actual record in DB,
  # other than associations being deleted like prices, still many callbacks querying 
  # at least 6 things.  This follows the deletion calls of associations by using 
  # raw/low level DB queries.
  # This should be updated according to more future association deletion.
  def really_destroy_without_callbacks!
    Spree::Variant.acts_as_list_no_update do
      Spree::Price.unscoped.where(id: self.prices.with_deleted.collect(&:id) ).delete_all
      Spree::StockItem.unscoped.where(id: self.stock_items.with_deleted.collect(&:id) ).delete_all
      self.images.each(&:destroy)
      self.variant_adoptions.delete_all
      Spree::Variant.unscoped.where(id: self.id).delete_all
    end
  end

  ##
  # Self, prices, images
  # @other_attributes [Hash] overriding self attribute values
  def clone_self_and_more(other_attributes = {})
    h = other_attributes.clone
    price_h = h.delete(:prices) || {}
    v = self.class.new( attributes.except('id', 'sku', 'created_at', 'updated_at', 'deleted_at').merge(h) )
    v.prices = self.prices.collect do|price|
      Spree::Price.new(price.attributes.except('id', 'variant_id', 'created_at', 'updated_at').merge(price_h))
    end
    v.option_value_variants = self.option_value_variants.collect{|ovv| Spree::OptionValueVariant.new(ovv.attributes.except('id', 'variant_id') ) }
    v.save
    v
  end

  ##
  # Expected this used for product.rep_variant
  # * pick other phantom seller  
  # * clone existing rep_variant  
  # * set clone to that other phantom seller
  # * update all removed vp’s adoptions, and images to point to clone
  # * update the item to point rep_variant_id to clone
  # * update product in search index
  def takedown!(record_review_status_code = nil)
    another_phantom = Spree::User.pick_phantom_sellers(1, self.product.seller_ids).first
    old_sku = sku
    v = clone_self_and_more(user_id: another_phantom.id)
    self.adoptions.update_all(variant_id: v.id)
    self.images.update_all(viewable_id: v.id)

    Spree::LineItem.joins(:order).where("state='cart'").where(variant_id: id).all.each(&:destroy)
    
    self.product.rep_variant_id = v.id # in case ES update_document doesn't reload
    self.product.update_columns(rep_variant_id: v.id)
    self.product.es.update_document

    self.update_columns(deleted_at: Time.now)
    v.update_columns(sku: old_sku)
    record_review_status_code ||= Spree::RecordReview.status_code_for('Listing Violation')
    Spree::RecordReview.create(record_type: self.class.to_s, record_id: self.id, 
      status_code: record_review_status_code)

    v
  end

  def create_phantom_variation_adoption!
    another_phantom = Spree::User.pick_phantom_sellers(1, adoptions.collect(&:user_id).uniq).first
    
    Spree::VariantAdoption.find_or_create_by(variant_id: id, user_id: another_phantom.id) do|va|
      va.prices = self.prices.collect do|_price|
        this_price = _price.amount.to_f * (1.0 + (20 + rand(20)) / 100.0 ) # >= 120%
        Spree::AdoptionPrice.new(currency: _price.currency, country_iso: _price.country_iso, amount: this_price)
      end
    end
  end

  # Pick phantom seller's VariantAdoption.  Supposedly worst rank.
  # Workaround for migration to add code column, so null initially, and then need to 
  # set a code for existing.
  def select_rep_variant_adoption
    va = self.adoptions.by_phantom_sellers.includes( :user ).first
    if va && va.code.blank?
      va.set_other_attributes
      va.save
    end
    va
  end

  ## 
  # Now direct SQL update query w/o going into prices table
  def reset_price_to!(lowest, highest )
    highest_price_conds = highest ? ['currency=? and amount > ?', Spree::Config[:currency], highest ] : nil
    lowest_price_conds = lowest ? ['currency=? and amount < ?', Spree::Config[:currency], lowest] : nil
    if highest
      self.prices.where(highest_price_conds).update_all(amount: highest)
    elsif lowest && v.price < lowest
      self.prices.where(lowest_price_conds).update_all(amount: lowest)
    end
    adoptions.by_unreal_users.includes(:default_price).each do|va|
      if highest
        va.prices.where(highest_price_conds).update_all(amount: highest)
      elsif lowest
        va.prices.where(lowest_price_conds).update_all(amount: lowest)
      end
    end
  end


  ##
  # Variant adoption generator has problem creating more than enough phantom 
  # variantions.  Just merge all into one.
  def clean_phantom_adoptions!(hard_delete = false)
    q = variant_adoptions.by_unreal_users
    base_va = q.first
    if q.count > 1
      other_ids = q.where("#{Spree::VariantAdoption.table_name}.id != #{base_va.id}").all.collect(&:id)
      self.line_items.where(variant_adoption_id: other_ids).update_all(variant_adoption_id: base_va.id)
      if hard_delete
        Spree::VariantAdoption.where(variant_id: self.id, id: other_ids).delete_all
        Spree::AdoptionPrice.where(variant_adoption_id: other_ids).delete_all
      else
        Spree::VariantAdoption.where(variant_id: self.id, id: other_ids).update_all(deleted_at: Time.now)
      end
    end
  end

  protected

  def set_defaults
    self.user_id ||= product.user_id
    self.price = nil if is_master && price.to_f <= 0.0
  end

  ##
  # There was a fault in original check of price.nil?: 0.0 value would pass through.
  def check_price
    if price.to_f <= 0.0 && Spree::Config[:require_master_price]
      return errors.add(:base, :no_master_variant_found_to_infer_price)  unless product&.master
      return errors.add(:base, :must_supply_price_for_variant_or_master) if self == product.master

      self.price = product.master.price
    end
    if price.present? && currency.nil?
      self.currency = Spree::Config[:currency]
    end
  end

  def set_update_attributes
    self.has_view_count_changed = true if view_count_changed?
  end

  def update_product
    if has_view_count_changed
      product.recalculate_view_count!
    end
  end

  ##
  # Might need this flag
  # If master is the not only lone variant, its position would be set to 0,
  # as a distinct indication that there're other variants for the product.
  def set_variant_data
    unless is_master
      self.product.master.update(position: 0) if self.product.master.position > 0
    end
  end

  def adopted?
    product&.user_id != self.user_id
  end

  ##
  # Seller related stats
  def update_stats
    if adopted? && !phantom?
      self.user.schedule_to_calculate_stats!
    end
  end

  ##
  # 1. Collectible OptionValue like brand from master.
  def update_product_rep_variant
    return if product.retail_site_id.to_i > 0 || phantom? # in future, may change

    if product.respond_to?(:auto_select_rep_variant_without_delay!)
      dj = Delayed::Job.for_record(product).all.find{|j| j.performable_method_name == 'auto_select_rep_variant!'}
      product.auto_select_rep_variant! if dj.nil?
    else
      product.auto_select_rep_variant!
    end
  end

  def prepare_words(words)
    return [''] if words.blank?
    a = words.split(/[,\s]/).map(&:strip)
    a.any? ? a : ['']
  end

  def disable_sku_validation?
    Spree::Config[:disable_sku_validation]
  rescue NoMethodError # preference could be not set
    false
  end
end

::Spree::Variant.prepend(::Spree::VariantDecorator) if ::Spree::Variant.included_modules.exclude?(Spree::VariantDecorator)