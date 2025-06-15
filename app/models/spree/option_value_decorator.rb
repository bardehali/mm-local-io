module Spree::OptionValueDecorator
  extend ActiveSupport::Concern

  # How the heck works in OptionTypeDecorator w/o check but not here
  STRIP_FROM_ATTRIBUTES ||= true unless const_defined?(:STRIP_FROM_ATTRIBUTES)
  UNACCEPTABLE_LETTERS_IN_NAME ||= /([^a-z\d\.&]+)/i unless const_defined?(:UNACCEPTABLE_LETTERS_IN_NAME)

  def self.prepended(base)
    base.extend ClassMethods

    base.include ::Searchable
    base.include OptionValueSearchable

    base.index_name "shoppn-option-values-#{Rails.env == 'staging' ? 'production' : Rails.env}"

    base.belongs_to :user, class_name: 'Spree::User', foreign_key: :user_id

    base.scope :with_names, lambda {|option_type_names|
        joins(:option_type).where("#{Spree::OptionType.table_name}.name IN (?)", option_type_names ) }
    base.scope :single_names, -> { where("name NOT LIKE '%/%' AND name NOT LIKE '% %'") }
    base.scope :multi_word_names, -> { where("name LIKE '%/%' OR name LIKE '% %'") }
    base.scope :for_public, -> { where("user_id is null or user_id=?", ::Spree::User.fetch_admin.id) }
    base.scope :for_user, lambda {|user_or_user_id| where("user_id is null or user_id=?", user_or_user_id.respond_to?(:id) ? user_or_user_id.id : user_or_user_id ) }

    base.scope :excluding_option_types, -> { where('option_type_id NOT IN (?)', Spree::OptionType.excluded_ids_from_users) }
    base.scope :includes_for_indexing, -> { includes(:option_type) }

    # cancan.accessible_by is different.  Custom values first
    base.scope :manageable_by, lambda {|user_id| joins(:option_type).where('user_id IS NULL OR user_id=?', user_id).order('user_id desc') }

    base.has_one :product_count_stat,
      -> { where(record_type:'Spree::OptionValueVariant', record_column:'option_value_id') },
      foreign_key:'record_id', class_name:'Spree::RecordStat'

    attr_accessor :variant_ids, :selected, :selected_other_option_value_ids

    base.before_save :normalize_fields

    # Override
    base.validates :name, presence: true, uniqueness: { scope: [:option_type_id, :user_id], allow_blank: true, case_sensitive: false }

    base.const_set 'ONE_VALUE_REGEXP', /\Aone\s+(\w+\s+)?(size|color|weight)/i

  end

  #####################################
  #
  module ClassMethods
    def accessible_by(ability, action = :index)
      self.manageable_by(ability.user.try(:id) )
    end

    def ransackable_attributes(auth_obj = nil)
      %w(name presentation option_type_id extra_value)
    end

    ##
    # @option_types [Array of Spree::OptionType] if provided, would limit option values of those.
    def search_for_matches(title, option_types = nil)
      should_conds = title.word_combos.collect{|w| { match_phrase:{presentation: w} } }
      must_conds = option_types ? option_types.collect{|ot| {match:{ option_type_id: ot.id } } } : []
      self.es.search(query:{bool:{should: should_conds, must: must_conds }})
    end

    def most_product_option_values(specific_option_type = nil)
      ot = nil
      if specific_option_type.is_a?(Spree::OptionType)
        ot = specific_option_type
      elsif specific_option_type.is_a?(String) && specific_option_type.present?
        ot = Spree::OptionType.where(name: specific_option_type).first
      end
      query = self.joins(:product_count_stat).includes(:product_count_stat).order('record_count desc')
      query = query.where(option_type_id: ot.id) if ot
      query
    end

    ##
    # @yield Spree::OptionValue, count (Integer)
    def save_product_counts(specific_option_type = nil, &block)
      query = specific_option_type ? specific_option_type.option_values : Spree::OptionValue.all
      query.each do|ov|
        cnt = Spree::OptionValueVariant.joins(:variant).where(option_value_id: ov.id, spree_variants:{ is_master: true } ).count;
        stat = Spree::RecordStat.find_or_initialize_by(
          record_type: 'Spree::OptionValueVariant', record_column: 'option_value_id', record_id: ov.id)
        stat.record_count = cnt
        stat.save

        yield ov, cnt if block_given?
      end
    end

    def brand
      find_by_name('brand')
    end

  end

  #################################
  #

  module OptionValueSearchable
    extend ActiveSupport::Concern

    included do
      include ::Elasticsearch::Model::Callbacks

      index_name "shoppn-products-#{Rails.env == 'staging' ? 'production' : Rails.env}"

      def self.settings_attributes
        {
          index: {
            analysis: {
              analyzer: {
                ngram_analyzer: {
                  tokenizer: :ngram_tokenizer,
                  filter: %w(lowercase)
                },
                autocomplete: {
                  type: :custom,
                  tokenizer: :standard,
                  filter: %i[lowercase autocomplete_filter]
                }
              },
              filter: {
                autocomplete_filter: {
                  type: :edge_ngram,
                  min_gram: 1,
                  max_gram: 25
                }
              },
              tokenizer: {
                  ngram_tokenizer: {
                  type: 'ngram',
                  min_gram: 1,
                  max_gram: 2
                }
              }
            }
          }
        }
      end

      settings settings_attributes do
        mappings dynamic: false do
          indexes :name, type: :keyword
          indexes :presentation, type: :text
          indexes :all_values, type: :text
          indexes :option_type_presentation, type: :text
          indexes :option_type_id, type: :integer
          indexes :user_id, type: :integer
          indexes :position, type: :integer
          indexes :created_at, type: :date
        end
      end
    end # included
  end

  #################################
  #

  ##
  # If extra_value is present w/ value, would take precedence over presentation.
  def extra_value_or_presentation
    extra_value.present? ? extra_value : presentation
  end

  def option_type_name
    option_type.try(:name)
  end

  def option_type_presentation
    option_type.try(:presentation)
  end

  def option_type_position
    option_type.position
  end

  def as_json(options = nil)
    json = super(options)
    json[:option_type_presentation] = option_type_presentation
    json
  end

  def as_indexed_json(options = {})
    json = as_json(except:[:updated_at])
    json[:all_values] = "#{presentation} #{extra_value}".strip
    json[:option_type_presentation] = option_type_presentation
    json
  end

  def to_s
    '<(%d) %s | %s | pos %d>' % [id, presentation || name, extra_value.to_s, position]
  end

  def product_count
    product_count_stat.try(:record_count)
  end

  def for_public?
    user_id.to_i == 0 || user_id == ::Spree::User.fetch_admin.id
  end

  ##
  # Show to general users, excluding admins.
  def show_to_users?
    option_type&.show_to_users?
  end

  def one_value?
    !presentation.match(Spree::OptionValue::ONE_VALUE_REGEXP).nil?
  end

  def normalize_fields
    if name
      self.name.gsub!(UNACCEPTABLE_LETTERS_IN_NAME, ' ')
      self.name.strip!
    end
  end

end

::Spree::OptionValue.prepend Spree::OptionValueDecorator if ::Spree::OptionValue.included_modules.exclude?(Spree::OptionValueDecorator)
