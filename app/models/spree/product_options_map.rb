##
# Controller to handle backend operations of Spree::OptionType of Spree::Product 
# and Spree::OptionValue of product's Spree::Variant's.
class Spree::ProductOptionsMap

  # If variant has option values that are de-selected, would simply delete without 
  # checking whether has other associations.
  LOOSE_DELETE_VARIANTS_OF_DESELECTED_OPTION_VALUES = true

  QUERY_INCLUDES_FOR_SORTING = [:option_values, :default_price, :prices, images:{ attachment_attachment:[:blob] }, user:[:spree_roles, :store => [:store_payment_methods] ]]

  attr_reader :user_id

  ##
  # @variant_includes [Array] default :option_value_variants; list of attributes for variants.includes during fetch of variants.
  # @options [Hash]
  #   :sort_order [String or Symbo] default :seller_based_sort_rank; can be other attribute/method of Spree::Variant
  #   :sort_direction [either :desc or :asc] default :desc to pair w/ default :seller_based_sort_rank for :sort_order
  #   :exclude_zero_value [Boolean] default true; whether to reject variants whose @sort_order is nil/zero, 
  #     for example, excluding 0 seller_rank of inactive sellers.
  #   :include_phantom_variants [Boolean] default false; whether to fetch any variant including phantom sellers'
  def initialize(product, user_id = nil, variant_includes = nil, options = {})
    @product = product
    @user_id = user_id
    @variant_includes ||= variant_includes || [:option_value_variants, :default_price, user:[:role_users], variant_adoptions:[user:[:role_users] ] ]
    @sort_order = options[:sort_order].try(:to_sym) || :seller_based_sort_rank
    @sort_direction = options[:sort_direction] == :asc ? :asc : :desc
    @exclude_zero_value = options[:exclude_zero_value] != false
    @include_phantom_variants = ( options[:include_phantom_variants] == true )
  end


  ##
  # Might be unnecessary in product update form that has OptionType fields set.
  # @keep_or_delete_existing [Boolean] If given list has some missing entries,
  #   would they be deleted or kept.
  # @force_delete [Boolean] If want to delete OptionType associations that 
  #   has option values that belong to variants.
  def sync_option_types(option_types_or_ids, keep_or_delete_existing = false, force_delete = false)
    option_type_ids = convert_to_array_of_ids(option_types_or_ids, Spree::OptionType)
    existing_option_type_ids = @product.product_option_types.collect(&:option_type_id)

    # Missing
    missing_ids = option_type_ids - existing_option_type_ids
    logger.debug "| sync_option_types w/ #{option_type_ids} vs existing #{existing_option_type_ids}"
    logger.debug "  missing_ids: #{missing_ids}"
    missing_ids.each{|ot_id| @product.product_option_types.create(option_type_id: ot_id) }

    # Deleting
    to_delete_ids = keep_or_delete_existing ? [] : existing_option_type_ids - option_type_ids
    if to_delete_ids.size > 0
      if force_delete
        @product.option_types.each(&:destroy)
      else
        @product.product_option_types.where(id: to_delete_ids).delete_all
      end
    end
  end


  ##
  # Would check, add to and delete existing set of option value variants.
  # Attributes used in @other_attributes_of_variant:
  #   :user_id [Integer] look for matching variants specific to this user
  #   :delete_existing_variants_not_included [Boolean] if there're other variants w/ combos 
  #     not in @option_value_ids, whether to delete them; default is LOOSE_DELETE_VARIANTS_OF_DESELECTED_OPTION_VALUES
  def sync_option_values(option_value_ids, other_attributes_of_variant = {})
    user_id = other_attributes_of_variant[:user_id]
    delete_existing_variants_not_included = other_attributes_of_variant.delete(:delete_existing_variants_not_included)
    delete_existing_variants_not_included = LOOSE_DELETE_VARIANTS_OF_DESELECTED_OPTION_VALUES if delete_existing_variants_not_included.nil?
    existing_ov_ids = [] # Array of [ov1, ov2], [ov1, ov4]
    single_ov_id_to_variant = {} # when combo only 1 OV, ov_id => variant

    variants_query = @product.variants_without_order.includes(:option_value_variants)
    if user_id
      variants_query = variants_query.by_this_user(user_id)
    elsif !Spree::Product::IS_ADMIN_A_SELLER
      variants_query = variants_query.owned_by_users
    end
    logger.debug "| sync_option_values (product #{@product.id}) variants count: #{variants_query.count}"

    return if option_value_ids.blank? && variants_query.count == 0

    variants_query.all.each do|v| 
      v_ov_ids = v.option_value_variants.collect(&:option_value_id)
      existing_ov_ids << v_ov_ids
      single_ov_id_to_variant[v_ov_ids.first] = v if v_ov_ids.size == 1
    end
    option_value_ids = option_value_ids.collect{|ov_id| ov_id.is_a?(Array) ? ov_id : [ov_id] }
    logger.debug "| option_value_ids #{option_value_ids.sort} VS\n| existing_ov_ids: #{existing_ov_ids.sort}"
    missing_ov_ids = option_value_ids - existing_ov_ids
    logger.debug "| missing_ov_ids #{missing_ov_ids}"

    missing_ov_ids.each do|ov_id_a|
      ids = ov_id_a.is_a?(Array) ? ov_id_a : [ov_id_a]
      v = ::Spree::Variant.new( other_attributes_of_variant.merge(
        product_id: @product.id, price: @product.variant_price || @product.price,
        option_value_variants: ids.collect{|ov_id| Spree::OptionValueVariant.new(option_value_id: ov_id) } 
      ) )
      r = v.save
    end

    if delete_existing_variants_not_included
      left_behind = (existing_ov_ids - option_value_ids)
      logger.debug "   left behind: #{left_behind.sort }"
      # images_count = left_behind.blank? ? {} :
      #  Spree::Image.where(viewable_type:'Spree::Variant', viewable_id: left_behind).group('viewable_id').count

      left_behind.each do|ov_id|
        # if images_count[ov_id].nil? delete variant
        find_variants_of_option_values(ov_id).each do|v|
          logger.debug "* deleting variant (#{v.id}) w/ ovs #{v.option_values.collect(&:id)}"
          v.destroy
        end
      end
    else
      logger.debug '  Ignore existing variants not in list @option_value_ids'
    end
  end


  ####################################
  # Accessors 

  ##
  # @option_values [Array of either OptionValue or its id]
  # @return [Array of Spree::Variant] not found would be empty
  def find_variants_of_option_values(option_values)
    ids = convert_to_array_of_ids(option_values, Spree::OptionValue)
    ids.sort!
    option_value_ids_to_which_map[ids] || []
  end

  ALL_VARIANTS_ADOPTED_CONVERTED = true

  def variants_for_user
    unless @variants_for_user
      @variants_for_user = if (@user_id == @product.user_id)
          @product.variants_including_master_without_order.by_this_user(@user_id).includes(*@variant_includes ).all.to_a
        else
          @product.variants_without_order.includes(*@variant_includes ).all.to_a
        end
        
        @variants_for_user.sort! do|x,y|
        x_value = x.send(@sort_order) || 0
        y_value = y.send(@sort_order) || 0
        @sort_direction == :asc ? (x_value <=> y_value) : (y_value <=> x_value)
      end
      @variants_for_user.reject!{|v| (v.send(@sort_order) || 0).to_f == 0.0 } if @exclude_zero_value && !@include_phantom_variants
    end
    @variants_for_user
  end

  def variant_adoptions_for_user
    unless @variant_adoptions_for_user
      user_variant_ids = @product.not_adopted_variants_including_master.joins(:variant_adoptions).distinct('id').select('id').collect(&:id)
      va_query = Spree::VariantAdoption.where(variant_id: user_variant_ids ).
        includes(:default_price, :user => [:role_users], :variant => [:option_value_variants] )
      if @user_id
        va_query = va_query.by_this_user(@user_id)
      end
      @variant_adoptions_for_user = va_query.to_a
      Spree::User.logger.debug "| va_query #{va_query.to_sql}"
      @variant_adoptions_for_user.sort! do|x,y|
        x_value = x.send(@sort_order) || 0
        y_value = y.send(@sort_order) || 0
        @sort_direction == :asc ? (x_value <=> y_value) : (y_value <=> x_value)
      end
      @variant_adoptions_for_user.reject!{|v| (v.send(@sort_order) || 0).to_f == 0.0 } if @exclude_zero_value && !@include_phantom_variants
    end
    @variant_adoptions_for_user
  end

    ##
  # @return [Hash of [Array of OptionValue#id] to [Array of Variant] ]
  def option_value_ids_to_variants_map
    unless @option_value_ids_to_variant_map
      build_maps
    end
    @option_value_ids_to_variant_map
  end

  # @return [Hash of [Array of OptionValue#id] to [Array of VariantAdoption] ]
  def option_value_ids_to_variant_adoptions_map
    unless @option_value_ids_to_variant_adoptions_map
      @option_value_ids_to_variant_adoptions_map = {}
      variant_adoptions_for_user.each do|va|
        k = va.option_value_variants.collect(&:option_value_id).sort
        list = @option_value_ids_to_variant_adoptions_map.add_into_list_of_values(k, va)
      end
    end
    @option_value_ids_to_variant_adoptions_map
  end

  ##
  # Depends on @user_id set.  If owner of product, would be @option_value_ids_to_variants_map; 
  # else would be @option_value_ids_to_variant_adoptions_map
  def option_value_ids_to_which_map
    @product.user_id == @user_id ? option_value_ids_to_variants_map : option_value_ids_to_variant_adoptions_map
  end

  ##
  # @option_valud_id [either Spree::OptionValue or Integer or Array of Integer ]
  def [](option_value_id)
    ids = option_value_id.is_a?(Spree::OptionValue) ? option_value_id.id : option_value_id
    option_value_ids_to_which_map[ids]
  end

  def keys
    option_value_ids_to_which_map.keys
  end

  def size
    option_value_ids_to_which_map.size
  end

  ##
  # Using @option_value_ids_to_variants_map, 
  # @option_value_id [Spree::OptionValue or Array of Integer]
  # @return [ Array of Spree::Variant or nil]
  def variant_for_option_values(option_value_id)
    ids = option_value_id.is_a?(Spree::OptionValue) ? option_value_id.id : option_value_id
    option_value_ids_to_variants_map[ids]
  end

  ##
  # @option_value_id [same passed to [] ]
  def has_variant_adoption_of_option_value?(option_value_id)
    !self[option_value_id].blank?
  end

  def to_s
    s = "Product(#{@product.id}), user_id=#{@user_id}"
    option_value_ids_to_which_map.each_pair do|ov_id, variants|
      s << "\n  #{ov_id}: #{variants.collect(&:id)}"
    end
    s
  end


  protected

  def logger
    Spree::Product.logger
  end

  ##
  # @list_or_object [one ApplicationRecord or Array of that]
  # @return [Array of @object_klass#id ]
  def convert_to_array_of_ids(list_or_object, object_klass)
    ( list_or_object.is_a?(Array) ? list_or_object : [list_or_object] ).collect do|object|
      object.is_a?(object_klass) ? object.id : object
    end
  end

  # Builds the @option_value_ids_to_variant_map from variants
  # @return [Hash] keys: Array of OptionValue#id sorted 
  #   values: Array of Variant that have selected of OptionValue
  def build_maps
    unless @option_value_ids_to_variant_map
      @option_value_ids_to_variant_map = {}
      variants_for_user.each do|v|
          k = v.option_value_variants.collect(&:option_value_id).sort
          #do|ovv|
          ##  single_ov_variants = @option_value_ids_to_variant_map[ovv.option_value_id] || []
           # @option_value_ids_to_variant_map[ovv.option_value_id] = single_ov_variants + [v]
           # ovv.option_value_id
          #end.sort
          list = @option_value_ids_to_variant_map.add_into_list_of_values(k, v)
        end
    end
    @option_value_ids_to_variant_map
  end

end
