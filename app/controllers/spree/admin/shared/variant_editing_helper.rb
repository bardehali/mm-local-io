##
# Dependent on load_resource to set @product for references.
module Spree::Admin::Shared::VariantEditingHelper
  extend ActiveSupport::Concern

  included do
    before_action :load_option_types_and_values, only: [:new, :edit, :list_same_item]
  end

  def owner_or_admin?
    @owner_or_admin ||= (spree_current_user&.id == @product.user_id || spree_current_user&.admin? )
  end

  # Convert parameters into product's attributes for later processing.
  # If option_value_ids is nil, possibly in other tabs such as Properties, sync of
  # option values would be skipped.
  def set_option_values
    taxon_ids = params[:product].try(:[], :taxon_ids)
    if taxon_ids.is_a?(String) && taxon_ids.present?
      params[:product][:taxon_ids] = taxon_ids = taxon_ids.split(',')
    end

    if (@product&.id.nil? || Spree::Product::ALLOW_TO_CHANGE_OPTION_TYPES_AFTER)
      if option_type_ids = params[:product].try(:[], :option_type_ids)
        params[:product][:option_type_ids] = option_type_ids = option_type_ids.split(',')
      end
    elsif params[:product][:option_type_ids]
      params[:product].delete(:option_type_ids)
    end

    if taxon_ids.present?
      @product.taxons = Spree::Taxon.includes(:option_types).where(id: taxon_ids).all
    end

    logger.debug "set_option_values --------------------\n| after conversion, params[:product]: #{params[:product]}"
    logger.debug "| taxons: #{@product.taxons.to_a}"
    @product.variant_price = params[:product].try(:[], :variant_price)

    if @product.taxons && %w(create).include?(params[:action])
      # Might be modified just before save by Spree
      option_types_after = @product.taxons.collect{|t| t.closest_related_option_types.all }.flatten.uniq
      # keep option types like brand
      option_types_after += @product.option_types.find_all{|ot| Spree::OptionType.collectible_option_types.include?(ot) } if @product.id
      @product.option_types = option_types_after
    end
    required_option_types = @product.option_types.find_all(&:required_to_specify_value?)

    option_value_ids = params[:variant].try(:[], :option_value_ids) || []
    option_value_ids.delete_if{|ids| ids.size <= required_option_types.size }

    used_option_value_ids = [] # if used in combos, wouldn't need single option value
    ( params[:variant].try(:[], :combo_option_value_ids) || params[:combo_option_value_ids] || [] ).each do|combo_option_value_ids|
      ids = combo_option_value_ids.split(',').collect(&:to_i).sort
      used_option_value_ids += ids
      option_value_ids << ids
    end

    # Single value ignored if no multiple (used to be required)
    ( params[:variant] || params ).each_pair do|pname, pvalue|
      if pname =~ /\Aoption_value_id_\d+\Z/i
        option_value_ids << pvalue.to_i if pvalue.to_i > 0 && required_option_types.size == 1 # && used_option_value_ids.exclude?(pvalue.to_i)
      end
    end if option_value_ids.none?{|_combo| _combo.is_a?(Array) && _combo.size > 1 }
    logger.debug "| option_value_ids: #{option_value_ids}"

    return if params[:variant].try(:[], :option_value_ids).nil? && option_value_ids.blank?

    @product.user_variant_option_value_ids = { spree_current_user.id => option_value_ids }

  end

  ##
  # Automatically adds color to list of option_type_ids.
  # Extra query set Spree::OptionValue#selected attribute based on product master's
  # existing Spree::OptionValueVariant entries.
  def load_option_types_and_values
    puts "|>> Loading Resources"
    load_resource if params[:id]
    if @product.try(:id)
      @color_option_type ||= @product.option_types.includes(:option_values).find(&:color?)
      puts "|>> Color Option Type: #{@color_option_type.inspect}"
      @size_option_type ||= @product.option_types.includes(:option_values).find(&:size?)
      puts "|>> Size Option Type: #{@size_option_type.inspect}"
    end
    if (taxon_ids = params[:product].try(:[], :taxon_ids) ).present?
      @product.taxons = Spree::Taxon.where(id: taxon_ids).includes(:related_option_types).all
      @product.taxons.each do|taxon|
        @color_option_type ||= taxon.related_option_types.all.collect(&:option_type).find(&:color?)
        @size_option_type ||= taxon.related_option_types.all.collect(&:option_type).find(&:size?)
      end
    end
    if @product.new_record?
      @color_option_type ||= ::Spree::OptionType.color
      @size_option_type ||= ::Spree::OptionType.sizes.first
    end

    if @product.new_record? || @product.option_type_ids.blank?
      logger.debug "| @size_option_type: #{@size_option_type}"
      logger.debug "| @color_option_type: #{@color_option_type}"

      @product.option_type_ids << @color_option_type.id unless @product.new_record?
      @product.option_type_ids.uniq!
    end

    if @product.try(:id) && @product.master
      if owner_or_admin?
        @color_option_values ||= @color_option_type ? @color_option_type.option_values.accessible_by( current_ability ).to_a : []
        owner_options_map = product_options_map(@product.user_id)
        @color_option_values.each do|ov|
          ov.selected = owner_options_map[ov.id].present?
        end
        logger.debug "| can edit, #{@color_option_values.size} color_option_values, #{@color_option_values.find_all(&:selected).size} selected"

      else # Other seller
        excluded_editor_ids = Set.new( [Spree::User.fetch_admin.id] )
        existing_color_ids = Set.new
        @variant_price = nil
        @product.variants_including_master.includes(:option_value_variants, :prices).each do|v|
          #logger.debug "  * (#{v.id}) by #{v.user_id}, $#{v.price}"
          # next if v.user_id.nil? || excluded_editor_ids.include?(v.user_id)
          @variant_price ||= v.price if v.user_id == spree_current_user&.id
          v.option_value_variants.each{|ovv| existing_color_ids << ovv.option_value_id }
        end
        @color_option_values = @color_option_type ? @color_option_type.option_values.where(id: existing_color_ids ).to_a : []
        @color_option_values.each do|ov|
          ov.selected = true # product_options_map(spree_current_user&.id)[ov.id]
        end
        @size_option_values = @product.hash_of_option_type_ids_and_values(true)[@size_option_type&.id]
        logger.debug "| other seller #{spree_current_user&.id} only has existing colors #{existing_color_ids}"
        logger.debug "  -> resulting count for seller B to select #{@color_option_values.count}"
        #logger.debug "     color_option_values: #{@color_option_values}"
      end
      # logger.debug "| size_option_type: #{@size_option_type}"
    end
  end

  ##
  # Different version of load_option_and_values.
  # This is more flexible, dynamic way to load related option types (according to either taxons
  # or existing option types).  And option types wouldn't only be color and then size.
  def preset_option_types_and_values
    load_resource if params[:id]

    if @product.try(:id)
      @option_types = @product.option_types
      if @option_types.blank?
        taxon_ids = params[:product].try(:[], :taxon_ids) || @product.classifications.collect(&:taxon_id)
        Spree::Taxon.where(id: taxon_ids).includes(:option_types).each do|v|
          v.option_types.each{|ot| @option_types << ot }
        end
      end
    end
    @option_types.uniq! if @option_types

    if @product.new_record? || @product.option_type_ids.blank?
      logger.debug "| @size_option_type: #{@size_option_type}"
      logger.debug "| @color_option_type: #{@color_option_type}"

      @product.option_type_ids << @color_option_type.id
      @product.option_type_ids.uniq!
    end

    if @product.try(:id) && @product.master
      if owner_or_admin?
        @color_option_values ||= @color_option_type.option_values.accessible_by( current_ability ).to_a
        owner_options_map = product_options_map(@product.user_id)
        @color_option_values.each do|ov|
          ov.selected = owner_options_map[ov.id].present?
        end
        logger.debug "| can edit, #{@color_option_values.size} color_option_values, #{@color_option_values.find_all(&:selected).size} selected"

      else # Other seller

        # This block handles the retrieval of option values (colors and sizes) for the product's variants
        # that can be edited by another seller (i.e., a seller who is not the original product owner).
        # It identifies which color options are available for selection based on the editable variants,
        # and it logs the relevant information for debugging purposes.


        editable_user_ids = Set.new( [@product.user_id, Spree::User.fetch_admin.id] )
        existing_color_ids = Set.new
        @product.variants_including_master.includes(:option_value_variants).each do|v|
          next unless v.user_id.nil? || editable_user_ids.include?(v.user_id)
          v.option_value_variants.each{|ovv| existing_color_ids << ovv.option_value_id }
        end
        @color_option_values = @color_option_type.option_values.where(id: existing_color_ids ).to_a
        @color_option_values.each do|ov|
          ov.selected = true # product_options_map(spree_current_user&.id)[ov.id]
        end
        @size_option_type ||= @product.option_types.find(&:size?)
        @size_option_values = @product.hash_of_option_type_ids_and_values(true)[@size_option_type&.id]


        logger.debug "| other seller only has existing colors #{existing_color_ids}"
        logger.debug "  -> resulting count for seller B to select #{@color_option_values.count}"
        #logger.debug "     color_option_values: #{@color_option_values}"
      end
      # logger.debug "| size_option_type: #{@size_option_type}"
    end
  end
end
