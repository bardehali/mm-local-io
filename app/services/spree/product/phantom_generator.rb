module Spree::Product::PhantomGenerator
  extend ActiveSupport::Concern
  included do
    include ActiveRecord::CallbackModifier
  end

  # Applies to VariantAdoption also.
  MAX_PHANTOM_VARIANT_RANGE = [1, 1]

  ##
  # This would try up to 3 levels of @selected_ovs
  # Block passed in would receive each combo of Spree::OptionValue; else
  # the array of combos would be collected and returned.
  # @selected_ovs [Array of [Array of Spree:OptionValue] ]
  def generate_all_option_value_combos(selected_ovs, &block)
    combos = []
    return combos if selected_ovs.blank?

    selected_ovs[0].each do|first_ov|
      if (second_option_values = selected_ovs[1])
        second_option_values.each do|second_ov|
          if (third_option_values = selected_ovs[2])
            third_option_values.each do|third_ov|
              combo = [first_ov, second_ov, third_ov]
              if block_given?
                yield combo
              else
                combos << combo
              end
            end
          else
            combo = [first_ov, second_ov]
            if block_given?
              yield combo
            else
              combos << combo
            end
          end
        end
      else
        combo = [first_ov]
        if block_given?
          yield combo
        else
          combos << combo
        end
      end
    end
    combos
  end

  def phantom?
    user_id.nil? || user.nil? || user.admin? || user.phantom_seller?
  end
  alias_method :phantom_product?, :phantom?

  def convert_into_phantom_product!(enforce_regardless_seller = false)
    lastv = generate_phantom_variants!(nil, enforce_regardless_seller).last
    update_conds = {}
    update_conds[:status_code] = Spree::RecordReview::MAX_ACCEPTABLE_STATUS_CODE if status == 'invalid'
    if lastv && (self.user_id.nil? || self.user_id == Spree::User.fetch_admin.id )
      self.variants_without_order.by_unreal_users.update_all(user_id: lastv.user_id)
      update_conds[:user_id] = lastv.user_id
    elsif lastv.nil? && enforce_regardless_seller
      self.variants_including_master_without_order.by_unreal_users.update_all(user_id: self.user_id, converted_to_variant_adoption: false)
      update_conds[:rep_variant_id] = select_rep_variant&.id || self.rep_variant_id
    end

    generate_phantom_variant_adoptions!

    self.update_columns(update_conds) if update_conds.size > 0
  end

  ##
  # Based on combos from the 1st 2 option types (sorted by position), create phantom variants
  # where master user has not selected.  For primary option type, like color, if master is
  # phantom seller, would iterate through all option values; else within master's existing option values.
  # Non-primary option type would have all option values used.
  # @keep_combos_unique [Boolean] Whether search for this picked/found phantom seller's
  # already existing variants w/ the combos of option values.
  # @return [Array of Spree::Variant]
  def fill_combos_with_phantom_variants!(keep_combos_unique = true)

    final_option_types = get_option_types_for_generation

    return original_variants if self.taxons.blank? || final_option_types.blank?

    picked_prices = pick_prices
    t = Time.now

    # create variants of all combos for one single master or phantom seller
    phantom_seller = pick_phantom_sellers(nil, self.seller_ids.size + 1).first

    created_variants = original_variants.includes(:option_values).to_a
    existing_combos = Set.new
    option_type_id_to_option_values = {}
    if keep_combos_unique
      created_variants.each do|v|
        existing_combos << v.option_values.collect do|ov|
          option_type_id_to_option_values.add_into_list_of_values(ov.option_type_id, ov)
          ov.id
        end
      end
    end

    lists_of_option_values = final_option_types.collect do|ot|
      final_ovs = if ot.primary? # && !phantom?
        existing_ovs = option_type_id_to_option_values[ot.id]&.uniq # no value of primary option type, give it one value like one color
        existing_ovs = [ot.one_option_value].compact if existing_ovs.blank?
        existing_ovs
      else
        ot.option_values_for_auto_run.to_a
      end
    end
    self.generate_all_option_value_combos( lists_of_option_values ).each do|ovs|
      v = nil
      ov_ids = ovs.first.is_a?(Integer) ? ovs : ovs.collect(&:id)
      unless keep_combos_unique && existing_combos.include?(ov_ids.sort )
        Spree::Variant.acts_as_list_no_update do
          v = Spree::Variant.new(product_id: self.id, user_id: phantom_seller.id)
          without_create_and_update_callbacks(v) do
            v.save(validate: false)
            ov_ids.each{|ov_id| Spree::OptionValueVariant.insert(variant_id: v.id, option_value_id: ov_id) }
            picked_prices.each do|_price|
              Spree::Price.insert(variant_id: v.id, currency: _price.currency,
                country_iso: _price.country_iso, amount: _price.amount, created_at: t, updated_at: t )
            end
          end
          created_variants << v
        end
      end
    end

  # seller.calculate_stats!
    created_variants
  end

  ##
  # @keep_combos_unique [Boolean] Whether search for this picked/found phantom seller's
  # already existing variants w/ the combos of option values.
  # @return [Array of Spree::Variant]
  def generate_phantom_variants!(keep_combos_unique = true, enforce_regardless_seller = false)
    created_variants = []
    return created_variants if self.taxons.blank? || (!enforce_regardless_seller && !self.user&.admin? && self.user&.phantom_seller? == false)
    picked_prices = pick_prices

    # create variants of all combos for one single master phantom seller
    pick_phantom_sellers.each_with_index do|seller, index|
      if index == 0
        final_option_types = get_option_types_for_generation
        logger.debug "| final_option_types: #{final_option_types}"
        next created_variants if final_option_types.empty?

        set_skip_callbacks

        existing_combos = Set.new
        if keep_combos_unique
          Spree::Variant.where(product_id: id, converted_to_variant_adoption: false).includes(:option_value_variants).each do|v|
            created_variants << v
            existing_combos << v.option_value_variants.collect(&:option_value_id).sort
          end
        end

        t = Time.now
        lists_of_option_values = final_option_types.collect do|ot|
          ot.option_values_for_auto_run.to_a
        end
        self.generate_all_option_value_combos( lists_of_option_values ).each do|ovs|
          v = nil
          ov_ids = ovs.first.is_a?(Integer) ? ovs : ovs.collect(&:id)
          unless keep_combos_unique && existing_combos.include?(ov_ids.sort )
            Spree::Variant.acts_as_list_no_update do
              v = Spree::Variant.new(product_id: self.id, user_id: seller.id)
              without_create_and_update_callbacks(v) do
                v.save(validate: false)
                ov_ids.each{|ov_id| Spree::OptionValueVariant.insert(variant_id: v.id, option_value_id: ov_id) }
                picked_prices.each do|_price|
                  Spree::Price.insert(variant_id: v.id, currency: _price.currency,
                    country_iso: _price.country_iso, amount: _price.amount, created_at: t, updated_at: t )
                end
              end
              created_variants << v
            end
          end
        end
      else # other sellers, create adoptions instead ===================

        adopted_variant_ids = Spree::VariantAdoption.where(variant_id: created_variants.collect(&:id), user_id: seller.id)
        created_variants.reject.each do|v|
          next if adopted_variant_ids.include?(v.id)
          Spree::VariantAdoption.create(variant_id: v.id, user_id: seller.id,
            prices: picked_prices.collect do|_price|
              Spree::AdoptionPrice.new(currency: _price.currency, country_iso: _price.country_iso, amount: _price.amount)
            end
          )
        end
      end

      # seller.calculate_stats!
    end # each seller

    created_variants
  end

  ##
  # Compared to using @generate_phantom_variants!, this only generates
  # VariantAdoption entries to existing variants.
  # @return [Array of Spree::Variant] variants used.
  def generate_phantom_variant_adoptions!
    created_variants = []
    picked_prices = pick_prices
    self.variants_including_master_without_order.includes(:option_value_variants, variant_adoptions:[ user:[:role_users] ]).each do|v|
      created_variants << v
      how_many = 1 - v.variant_adoptions.by_phantom_sellers.count # all.find_all(&:has_acceptable_adopter?).size
      next if how_many < 1
      variant_user_ids = v.variant_adoptions.collect(&:user_id).uniq
      pick_phantom_sellers(variant_user_ids, variant_user_ids.size + how_many).each do|seller|
        Spree::VariantAdoption.find_or_create_by(variant_id: v.id, user_id: seller.id) do|va|
          va.prices = picked_prices.collect do|_price|
            Spree::AdoptionPrice.new(currency: _price.currency, country_iso: _price.country_iso, amount: _price.amount)
          end
        end
      end
    end
    created_variants
  end

  ##
  # @yield provides each of the new phantom_seller users to fill up the wanted count in range of
  # MAX_PHANTOM_VARIANT_RANGE
  # @return [Array of Spree::User] joined list of users: newly created/picked
  def pick_phantom_sellers(existing_user_ids = nil, how_many = nil, &block)
    how_many ||= pick_max_count.to_i
    existing_user_ids ||= seller_ids

    logger.debug "| pick_phantom_sellers for (#{id}): phantom? #{phantom?}, existing #{existing_user_ids.size} vs #{how_many} wanted"

    more_phantom_users = []
    if existing_user_ids.size - 1 < how_many
      Spree::User.pick_phantom_sellers(how_many, existing_user_ids.size).each do|u|
        yield u if block_given?
        more_phantom_users << u
      end
    end
    more_phantom_users
  end

  def generate_product_reviews!(dry_run = false)
    set_skip_callbacks

    logger.debug "| Product #{id} to generate_product_views while #{self.reviews.count} reviews"
    review_g = Ioffer::ProductReviewGenerator.new(dry_run: dry_run, user_list_name: 'phantom_product_reviewers')
    review_g.batch_run_for([self])
  end

  handle_asynchronously :generate_product_reviews!, queue:'ITEM_CONTENT' if Rails.env.production?


  protected

  def set_skip_callbacks
    self.skip_after_more_updates = true
    #[:create_stock_items, :set_master_out_of_stock].each do|m|
    #  Spree::Variant.skip_callback(:create, :after, m)
    #end
    Spree::Variant.skip_callback(:update, :after, :update_product)
  rescue ArgumentError => callback_e
    # rspec tests just don't have these callbacks set
  end

  def get_option_types_for_generation
    final_option_types = self.option_types.includes(:option_values).all.reject(&:brand?).sort_by(&:position)[0,2]
    if final_option_types.find(&:color?).nil?
      final_option_types.insert(0, Spree::OptionType.one_color)
      final_option_types.sort_by!(&:position)
    end
    final_option_types
  end

  ##
  # @return [Array of Spree::Price] w/ increased prices by currency
  def pick_prices(variant = nil)
    t_price = self.taxons.includes(:taxon_prices).first&.taxon_prices.to_a.shuffle.first&.price
    t_price = nil if t_price.to_f == 0.0
    list = master.prices.to_a.collect do|p|
      Spree::Price.new(variant_id: variant&.id, currency: p.currency, amount: t_price || p.amount )
    end
    list << Spree::Price.new(variant_id: variant&.id, currency: 'USD', amount: t_price || self.price ) if list.blank?
    list
  end

  ##
  # Random max within range
  def pick_max_count
    MAX_PHANTOM_VARIANT_RANGE.min + rand(MAX_PHANTOM_VARIANT_RANGE.max - MAX_PHANTOM_VARIANT_RANGE.min)
  end
end
