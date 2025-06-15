module Spree::Product::Cleaner
  extend ActiveSupport::Concern

  def ensure_images_processed!
    self.variants_including_master.each do|v|
      v.images.each(&:ensure_attachment_variants_processed!)
    end
  end

  def clean_categories!(dry_run = true)
    taxons = self.taxons.includes(:option_types).to_a.sort do|x,y|
      x.sort_rank = calculate_taxon_sort_rank(x)
      y.sort_rank = calculate_taxon_sort_rank(y)
      y.sort_rank <=> x.sort_rank
    end

    if dry_run
      taxons.each do|t|
        logger.debug "%6d for %s (%d) w/ options %s" % [t.sort_rank.to_i, t.breadcrumb, t.id, t.option_types.collect(&:name).join(' | ')]
      end
    end

    keeping_option_types = taxons.first.option_types
    ots_to_delete = []
    1.upto(taxons.size - 1).each do|i|
      t = taxons[i]
      t.option_types.each{|_ot| ots_to_delete << _ot if keeping_option_types.exclude?(_ot) }
      unless dry_run
        self.classifications.where(taxon_id: t.id).delete_all
      end
    end
    self.option_types.each{|_ot| ots_to_delete << _ot if keeping_option_types.exclude?(_ot) }

    ots_to_delete.uniq!
    ots_to_delete.each{|_ot| remove_use_of_option_type(_ot, dry_run) if _ot.show_to_users? && _ot.name.match(/\Aone\s(size|color)/i).nil? }
  end

  ##
  # This would delete each variant using 1 of @option_type's option_value.
  def remove_use_of_option_type(option_type, dry_run = true)
    ov_ids = option_type.option_values.collect(&:id)
    should_delete_pot = 
      if option_type.color? && (one_color = option_type.one_color_option_value)
        ov_ids.delete(one_color.id)
        false
      elsif option_type.size? && (one_size = option_type.one_size_option_value)
        ov_ids.delete(one_size.id)
        false
      else
        true
      end
    logger.debug "----- removing_use_of #{option_type.to_s}, delete? #{should_delete_pot}" if dry_run
    
    begin
      Spree::Variant.skip_callback(:update, :after, :update_product)
      Spree::Variant.skip_callback(:destroy, :after, :update_product_rep_variant)
    rescue Exception 
    end
    
    self.variants.in_batches(of: 50) do|subq|
      subq.joins(:option_value_variants).where("option_value_id IN (?)", ov_ids).each do|v|
        if dry_run
          logger.debug "  * deleting variant (#{v.id}) #{v.sku_and_options_text}"
        else
          v.line_items.count.zero? ? v.really_destroy_without_callbacks! : v.destroy
        end
      end
    end
    self.product_option_types.where(option_type_id: option_type.id).delete_all if !dry_run && should_delete_pot
  end

  ##
  # Rules from Niel:
  # First we should fix the category color/size mapping. Any 1st, 2nd and 3rd level category that 
  # still doesn't have "Color (General Color)" option type add it to the Category.
  # Any category that doesn't have a size option type give it "One Size (One Size)". 
  # That should give all remaining categories a color and size option type, so That
  # will be consistent at the posting form level. 
  # For all items with 25+ colors give it One Color x the size mapping for that item's category. 
  # Delete the rest of the variants.
  # @too_many_limit [Integer] when count of variants w/ colors >= this, would replace w/ one color.
  def clean_many_colors!(dry_run = true, too_many_limit = 25)
    color_ots = self.option_types.all.find_all(&:color?)
    return [] if color_ots.empty?

    color_ots.each do|color_ot|
      ov_ids = color_ot.option_values.collect(&:id)
      one_color = color_ot.one_color_option_value

      q = self.variants.joins(:option_value_variants).where("option_value_id IN (?)", ov_ids)
      color_vcount = q.count
      if color_vcount >= too_many_limit
        one_color_combo = nil # skip duplicate one color + size
        vattr = nil
        other_ov_ids = Set.new
        q.all.each do|v|
          combo = v.option_value_variants.collect(&:option_value_id).sort
          if one_color && combo.include?(one_color.id)
            one_color_combo = combo
            next
          else
            v.option_value_variants.each do|ovv|
              other_ov_ids << ovv.option_value_id if ov_ids.exclude?(ovv.option_value_id)
            end
          end
          vattr ||= v.attributes
          if dry_run
            logger.debug "  * deleting variant (#{v.id}) #{v.sku_and_options_text}"
          else
            v.line_items.count.zero? ? v.really_destroy_without_callbacks! : v.destroy
          end
        end
        unless one_color.nil?
          other_ov_ids.each do|other_ov_id|
            next if one_color_combo == [one_color.id, other_ov_id].sort
            new_v = Spree::Variant.new(vattr.except('id', 'option_value_variants') )
            new_v.option_value_variants = [ 
              Spree::OptionValueVariant.new(option_value_id: one_color.id),
              Spree::OptionValueVariant.new(option_value_id: other_ov_id) ]
            if dry_run
              logger.debug "  + creating One Color variant, valid? #{new_v.valid?}, #{new_v.errors.messages}"
            else
              new_v.save
            end
          end
        end
      end
    end
  end

  ##
  # During conversion of all-on-variants adoptions to variant-to-many-adoptions 
  # structure, although redundant variants other than 1st set of color x size combo variants,
  # would have converted_to_variant_adoptions=true, their created VariantAdoption 
  # might not have moved to 1st set of variants.
  def move_wrong_variant_adoptions!(dry_run = false)
    primary_h = {} # combo => v
    secondary_h = {} # combo => [ [VariantAdoption] ]
    s = ''
    include_list = dry_run ? [{adoptions:[ user:[:role_users] ] }, { option_values:[:option_type] } ] : [:option_value_variants, :adoptions]
    self.variants_including_master_without_order.includes(*include_list).order('converted_to_variant_adoption asc').each do|v|
      combo = v.option_value_variants.collect(&:option_value_id).sort
      if dry_run
        s << "%11d | %40s | %40s | %5s | %s\n" % [v.id, v.user.to_s, v.sku_and_options_text, v.converted_to_variant_adoption.to_s, v.option_values.collect(&:id).sort.collect(&:to_s).join(',') ]
        v.adoptions.includes(:user).each do|va|
          next if va.user.phantom_seller?
          s << "%30s adoption: %11d | %40s\n" % ['', va.id, va.user.to_s]
        end
      end
      if v.converted_to_variant_adoption
        secondary_h.add_into_list_of_values(combo, v.adoptions)
      else
        primary_h[combo] ||= v
      end
    end
    if dry_run
      puts s
    end
    ( primary_h.keys | secondary_h.keys ).each do|k|
      if (secondary_list = secondary_h[k].try(:flatten) )
        if (primary_v = primary_h[k] )
          if dry_run
            puts "  * Moving to variant #{primary_v.id} for adoptions: #{secondary_list.collect(&:id) }"
          else
            Spree::VariantAdoption.where(id: secondary_list.collect(&:id) ).update_all(variant_id: primary_v.id)
          end
        end
      end
    end
  end


  ##
  # There can be variants created that got generated or posted by users multiple
  # times with same combos of option values.  
  # This would try to delete those:
  #   1) the combo already has other variants w/ real user adoptions, delete empty or phantom only variant
  #   2) else later ones or not-added-to-cart ones
  def clean_duplicate_variants!(dry_run = false)
    combo_h = {} # combo option_value.id => list of variants
    Spree::Variant.includes(option_values:[:option_type], user:[:role_users] ).where(is_master: false, product_id: id).each do|v|
      k = v.option_values.reject{|ov| ov.one_value? || ov.option_type.brand? }.collect(&:presentation).sort
      combo_h.add_into_list_of_values(k, v)
    end
    deleted_ids = []
    # one_color_ov = Spree::OptionType.find_by(name: 'One Color').one_color_option_value
    combo_h.each_pair do|k, vlist|
      chosen = k.blank? ? master : vlist.first
      if vlist.size > 1 || chosen.is_master
        if chosen.nil? || chosen.variant_adoptions.not_by_unreal_users.count == 0
          real_adopted = vlist.find do|v| 
            v.id != chosen&.id && (chosen.nil? || v.variant_adoptions.not_by_unreal_users.count > 0 || chosen.adoptions.count == 0)
          end
          if real_adopted 
            chosen = real_adopted
            if dry_run
              puts "Variant combo #{k} set real adopted to #{real_adopted.id}"
            end
          end
        
        else # has some real adoptions
          # let the other method to merge one to another
        end

        vlist.each do|v|
          next if v.id == chosen&.id
          line_items_count = Spree::LineItem.where(variant_id: v.id).count
          #should_delete = (line_items_count == 0)
          if dry_run
            puts "- moving variant #{v.id} $#{v.price} by #{v.user.to_s}"
          else
            v.move_to_another_variant!(chosen)
            # v.destroy # do batch
          end
          deleted_ids << v.id
        end
      end
    end
    unless dry_run # skips after_calls
      Spree::Variant.where(id: deleted_ids).update_all(deleted_at: Time.now)
      Spree::Price.where(variant_id: deleted_ids).update_all(deleted_at: Time.now)
    end
    deleted_ids
  end

  ##
  # Only converted_to_variant_adoption: false.
  # Cannot use straight joined SQL update all query because of prices in other tables
  def reset_variant_price_to!(lowest, highest )
    self.variants_including_master_without_order.each do|v| #where(converted_to_variant_adoption: false).each do |v| 
      v.reset_price_to!(lowest, highest)
    end.class
  end

  protected

  ##
  # Factors: depth, women's or mens of specific
  def calculate_taxon_sort_rank(taxon)
    score = taxon.depth * 100
    cats = taxon.categories_in_path
    breadcrumb = taxon.breadcrumb
    is_womens = (breadcrumb =~ /\bwomen\'?\b/i)
    if cats.empty?
      score = 0
    elsif is_womens && [Spree::Taxon.bags_and_purses.id, Spree::Taxon.womens_clothing.id].include?(cats.last.id)
      score += 350
    elsif [Spree::Taxon.shoes_sneakers.id].include?(cats.last.id) && (breadcrumb =~ /\bmen\'?\b/i )
      score += 300
    end
    score
  end
end