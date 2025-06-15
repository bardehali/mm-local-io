module Spree::OptionTypeDecorator
  extend ActiveSupport::Concern

  VALID_OPTION_NAME_REGEX ||= /^(\w+\s+)?(\w{2,}\s+)?(types?|category|name|colou?rs?|sizes?|number|no|sku|brand|width|length|height|diameter|radius|thickness|area|waist|bust|collar|weight|depth|models?|material|fabric|quality|quantity|count|pieces?|style|group|range|age|gender|level|class|capacity|time|date|life|season|quantity|version|edition|mode|port|payment|pattern|price|cost|charge|fee|rate|frequency|response|speed|bandwidth|volume|shape|method|current|voltage|percentage|ratio|frequency|condition|code|sleeve|sensitivity|grade|rating|platform|protocol|operating\s+system|format|angle|interface|standard)$/i

  DEFAULT_CACHE_KEY ||= 'DEFAULT_OPTION_TYPES'
  DEFAULT_OPTION_NAMES ||= ['color', 'clothing color', 'general color', 'size', 'clothing size', 'shoe size']
  CATEGORY_NAMES_TO_OPTION_TYPE_NAMES_MAP ||= {
    /shoes?\s*\z/i => ['color', 'clothing color', 'General Color', 'shoe size'],
    /clothing|clothes/i => ['color', 'clothing color', 'General Color', 'size', 'clothing size']
  }
  CUSTOM_TEMPLATES_MAP ||= {
    /\bcolor\Z/i => 'color_box'
  }

  COLLECTIBLE_NAMES ||= %w(brand)

  attr_accessor :selected_option_values

  def self.prepended(base)
    base.extend ClassMethods

    base.has_many :option_values_for_public, -> { for_public }, class_name:'Spree::OptionValue'

    base.validate :check_name
    base.after_save :clear_cache

    base.class_variable_set(:@@one_color, nil)
    base.class_variable_set(:@@one_size, nil)
  end

  module ClassMethods
    

    @@collectible_ones = nil
    @@excluded_ids_from_users = nil
    
    def valid_option_name?(name = '')
      name.blank? ? false : !name.to_sanitized_keyword_name.match(VALID_OPTION_NAME_REGEX).nil?
    end

    ##
    # Iterates over list of category names, and find matches and their paired option type names
    # @category_names <Array of String>
    def default_option_types(category_names = [])
      option_names = Set.new
      category_names.each do|category_name|
        CATEGORY_NAMES_TO_OPTION_TYPE_NAMES_MAP.each_pair do|k, v|
          option_names += v if k =~ category_name
        end
      end
      self.where(name: option_names.to_a )
    end

    ##
    # @return <Collection of Spree::OptionType>
    def collectible_option_types
      unless @@collectible_ones
        @@collectible_ones = where(name: COLLECTIBLE_NAMES).all
      end
      @@collectible_ones
    end

    def colors
      @@color_option_types ||= self.where(name: ['color', 'clothing color', 'general color'] ).includes(:option_values)
    end

    def color
      @@color ||= colors.find{|c| c.name =~ /general\s+color\Z/i } || colors.first
    end

    def sizes
      @@size_option_types ||= self.where("presentation LIKE '%size%' OR name LIKE '%size%'").includes(:option_values)
    end

    def brand
      @@brand_option_type ||= self.where(name:'brand').first
    end

    def one_size
      one_option_one_value_type('size')
    end

    def one_color
      one_option_one_value_type('color')
    end

    ##
    # Common build method.
    # @type_name [String] like 'color'
    # @type_value [String] like 'color'; else would be that of @type_name
    def one_option_one_value_type(type_name, type_value = nil)
      one_name = "one #{type_name}"
      option_type = class_variable_get("@@one_#{type_name.downcase}".to_sym)
      option_type ||= Spree::OptionType.where(name: one_name).includes(:option_values).first
      unless option_type
        option_type = Spree::OptionType.create(name: one_name, presentation: one_name.titleize,
          filterable: true )
        option_type.option_values.create(name: type_value || one_name, presentation: (type_value || one_name).titleize )
        class_variable_set("@@one_#{type_name.downcase}".to_sym, option_type)
      end
      option_type
    end

    def show_to_users?(name)
      name.match( /\b(brand)\b/i ).nil?
    end

    def excluded_ids_from_users
      @@excluded_ids_from_users ||= [brand.id]
    end
  end

  ################################
  # Instant methods

  def to_s
    "(#{id}) #{presentation || name}, @ #{position}, searcable? #{searchable_text}, filter? #{filterable}"
  end

  ##
  # @specific_user <Spree::User> If specified, would be option_values only accessible_by that.
  def as_json_with_option_values(specific_user = nil)
    json = as_json(except: [:created_at, :updated_at])
    list = specific_user ? option_values.accessible_by(::Spree::Ability.new(specific_user))
      : option_values.for_public
    json[:option_values] = list.collect{|v| v.as_json(except:[:created_at, :updated_at] ) }
    json
  end

  ##
  # Only those option values that have products/variants using them
  def used_option_values
    ov_ids = option_values.joins(:option_value_variants).
      select("#{Spree::OptionValue.table_name}.id").collect(&:id).uniq
    ::Spree::OptionValue.where(id: ov_ids ).order('position asc')
  end

  def show_to_users?
    self.class.show_to_users?(name)
  end

  ##
  # May change in future.
  def primary?
    color?
  end

  def color?
    !name.match(/\bcolors?\b/i).nil?
  end

  def one_color_option_value
    @one_color ||= self.option_values.where(name: ['one color', 'one_color', 'one available color'] ).first
  end

  def size?
    !(/\bsizes?|waist|lengths?\Z/i.match(presentation || name) ).nil?
  end

  def one_size_option_value
    @one_size ||= self.option_values.where("name like 'one%size'").first
  end

  ##
  # General return of this option type's one value such as One Color in some color option type, or One Size in some size option type.
  # @return [Spree::OptionValue or nil]
  def one_option_value
    if color?
      one_color_option_value
    elsif size?
      one_size_option_value
    else
      nil
    end
  end

  def brand?
    id == self.class.brand.id
  end

  def required_to_specify_value?
    (color? && name.match(/\bone\s+color/i).nil? ) || (size? && name.match(/\bone\s+size/i).nil? )
  end

  ##
  # Instead of full list of option values, for auto-run script, would provide customized 
  # set of option values, for example, Women's combined sizes would only provide letter sizes 
  # while in record there r also number sizes.
  # @return [Array of Spree::OptionValue]
  def option_values_for_auto_run
    final_option_values = if color? 
      [one_color_option_value].compact
    elsif name =~ /Women\'?s\s+Combined Sizes/i
      option_values.all.find_all{|ov| ov.presentation =~ /\A[a-z]+\Z/i && ov.presentation.match(/\Axxs|xxl\Z/i).nil? }
    else
      option_values.to_a
    end
    one_value_index = final_option_values.find_index(&:one_value?)
    final_option_values.delete_at(one_value_index) if one_value_index && final_option_values.size > 1
    final_option_values
  end

  def filtered_option_values_for(record)
    if record.is_a?(Spree::Product) && (color? || size?)
      multiple_values = false
      record.taxons.each do|taxon|
        taxon_cats = taxon.cached_self_and_ancestors.to_a
        taxon_cats.shift if taxon_cats.first.name =~ /categories\Z/i
        if (taxon_cats.first.name =~ /\b(clothing|sneakers?|shoes?|sports?|[a-z]+wear)\b/i )
          multiple_values = true
        end
      end
      multiple_values ? option_values : [one_color_option_value]
    else
      option_values
    end
  end

  protected

  def check_name
    unless self.class.valid_option_name?(name)
      self.errors.add(:name)
    end
  end

  def clear_cache
    Rails.cache.delete(DEFAULT_CACHE_KEY)
  end
end

::Spree::OptionType.prepend Spree::OptionTypeDecorator if ::Spree::OptionType.included_modules.exclude?(Spree::OptionTypeDecorator)