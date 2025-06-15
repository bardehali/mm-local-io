module Spree::TaxonDecorator

  def self.prepended(base)
    base.attr_accessor :token, :selected, :sort_rank

    base.scope :under_categories, -> { where(taxonomy_id: ::Spree::Taxonomy.categories_taxonomy.id) }
    base.scope :exclude_caetgories_root, -> { where('id != ?', ::Spree::Taxonomy.categories_taxonomy.root.id) }

    base.has_many :related_option_types, -> { where(record_type:'Spree::Taxon') }, foreign_key: :record_id, class_name: 'Spree::RelatedOptionType'
    base.has_many :option_types, through: :related_option_types

    base.has_many :searchable_record_option_types, -> { where(record_type:'Spree::Taxon') }, foreign_key: :record_id, class_name: 'Spree::SearchableRecordOptionType'
    base.has_many :searchable_option_types, through: :searchable_record_option_types,class_name:'Spree::OptionType', source: :option_type

    base.has_many :mapped_site_categories, class_name:'SiteCategory', foreign_key:'mapped_taxon_id'

    base.has_one :product_count_stat, 
      -> { where(record_type:'Spree::Classification', record_column:'taxon_id') }, 
      foreign_key:'record_id', class_name:'Spree::RecordStat'
    
    base.has_many :taxon_prices, class_name:'Spree::TaxonPrice', dependent: :destroy

    base.whitelisted_ransackable_attributes = ['id', 'name', 'taxonomy_id', 'lft', 'rgt', 'depth']

    base.extend ClassMethods
  end

  ################################
  module ClassMethods

    ##
    # Follow the @breadcrumb, try to traverse deeper following names of each level
    # @breadcrumb [String] like "Shoes & Sneakers > Men's Shoes > Sneakers"
    def parse_breadcrumb(breadcrumb)
      cat_levels = breadcrumb.split(' > ')
      deepest_level = ::Spree::Taxonomy.categories_taxonomy.root
      cat_levels.each do|cat_name|
        match_under = deepest_level.children.where(name: cat_name).first
        next if match_under.nil?
        deepest_level = match_under
      end
      deepest_level
    end

    def bags_and_purses
      Rails.cache.fetch('taxon.bags_and_purses', expires_in: 1.week) do
        t = Spree::Taxonomy.categories_taxonomy.taxons.where(name: ['Bags & Purses', 'Bags and Purses'] ).first
        unless t
          t = Spree::Taxon.create(name:'Bags & Purses', meta_title:'Bags & Purses', taxonomy_id: Spree::Taxonomy.categories_taxonomy.id)
          t.move_to_child_of(Spree::Taxonomy.categories_taxonomy.root)
        end
        t
      end
    end

    def womens_clothing
      Rails.cache.fetch('taxon.womens_clothing', expires_in: 1.week) do
        t = Spree::Taxonomy.categories_taxonomy.taxons.where(name: ['Women Clothing', 'Womens Clothing', "Women's Clothing"] ).first
        unless t
          t = Spree::Taxon.create(name:"Women's Clothing", meta_title:"Women's Clothing", taxonomy_id: Spree::Taxonomy.categories_taxonomy.id)
          t.move_to_child_of(Spree::Taxonomy.categories_taxonomy.root)
        end
        t
      end
    end

    def mens_clothing
      Rails.cache.fetch('taxon.mens_clothing', expires_in: 1.week) do
        t = Spree::Taxonomy.categories_taxonomy.taxons.where(name: ['Men Clothing', 'Mens Clothing', "Men's Clothing"] ).first
        unless t
          t = Spree::Taxon.create(name:"Men's Clothing", meta_title:"Men's Clothing", taxonomy_id: Spree::Taxonomy.categories_taxonomy.id)
          t.move_to_child_of(Spree::Taxonomy.categories_taxonomy.root)
        end
        t
      end
    end

    def shoes_sneakers
      Rails.cache.fetch('taxon.shoes_sneakers', expires_in: 1.week) do
        t = Spree::Taxonomy.categories_taxonomy.taxons.where(name: ['shoes sneakers', 'shoes and sneakers', "shoes & sneakers"] ).first
        unless t
          t = Spree::Taxon.create(name:"Shoes & Sneakers", meta_title:"Shoes & Sneakers", taxonomy_id: Spree::Taxonomy.categories_taxonomy.id)
          t.move_to_child_of(Spree::Taxonomy.categories_taxonomy.root)
        end
        t
      end
    end
  end


  ################################

  def product_count
    product_count_stat.try(:record_count)
  end

  def is_category?
    taxonomy_id == Spree::Taxonomy.categories_taxonomy.id
  end

  def cached_self_and_ancestors
    Rails.cache.fetch("taxon.#{id}.self_and_ancestors", expires_in: 1.day) do 
      self.self_and_ancestors.all
    end
  end

  # @depth [Integer] how many more levels to go deeper to collect taxons; default would be deepest - self.depth
  def self_and_subcategories(depth = nil)
    depth ||= Spree::Taxon.select('depth').order('depth desc').first.depth - self.depth
    all_taxons = [self]
    # skip recursive methods
    if depth >= 1
      self.children.each do|second|
        all_taxons << second
        if depth >= 2
          second.children.each do|third|
            all_taxons << third
          end
        end
      end
    end
    all_taxons
  end

  ##
  # @return [String]
  def breadcrumb(separator = ' > ')
    list = cached_self_and_ancestors.collect(&:name)
    list.shift if list[0] =~ /\Acategories\Z/i
    list.join(separator)
  end

  def pretty_name
    breadcrumb(' -> ')
  end

  ##
  # Reverse back to just before Categories root, meaning the top categories.
  # @return <Array of Spree::Taxon>
  def categories_in_path(&block)
    list = []
    cached_self_and_ancestors.each do|cat|
      if cat.name != 'Categories' && cat.depth.to_i > 0
        yield cat if block_given?
        list.insert(0, cat)
      end
    end
    list
  end

  def closest_related_option_types
    Spree::RelatedOptionType.closest_option_types(self.class.to_s, id)
  end

  def closest_searchable_option_types
    Spree::SearchableRecordOptionType.closest_option_types(self.class.to_s, id)
  end

  # @return [Spree::TaxonPrice or nil]
  def next_taxon_price(which_currency = nil)
    query_for_taxon_prices(which_currency).all.sort{|x,y| x.last_used_product_id.to_i <=> y.last_used_product_id.to_i }.first
  end

  # Compare to the range of TaxonPrice amounts.  If no TaxonPrice, would return true.
  def is_price_within_range?(price, currency = nil)
    t_prices = self.taxon_prices.where(currency.present? ? { currency: currency } : nil).all.collect(&:price).sort
    t_prices.blank? ? true : (price.to_f >= t_prices.first && price.to_f <= t_prices.last)
  end

  ##
  # @return [Spree::TaxonPrice or nil]
  def floor_taxon_price(which_currency = nil)
    query_for_taxon_prices(which_currency).order('price asc').first
  end

  ##
  # Inserts all items in self category and subcategories into @product_list.
  # Deletes all from @product_list since last insert time.
  def populate_products_into!(product_list)
    taxon_ids = [self.id]
    self.children.each do|second|
      taxon_ids << second.id
      second.children.each do|third|
        taxon_ids << third.id
      end
    end.class

    latest_add_time = product_list.product_list_products.order('created_at desc').first&.created_at || 
    Spree::Product.joins(:classifications).where("taxon_id IN (?)", taxon_ids).first.created_at  

    Spree::Product.joins(:classifications).where("taxon_id IN (?)", taxon_ids).in_batches do|subq|
      subq.each do|p| 
        product_list.product_list_products.find_or_create_by(product_id: p.id)
      end
    end

    Spree::Product.joins(:classifications).where("taxon_id IN (?)", taxon_ids).
      where("#{Spree::Product.table_name}.deleted_at >= ? OR (#{Spree::Product.table_name}.updated_at >= ? AND iqs <= 0)", latest_add_time, latest_add_time).in_batches do|subq|
        subq.each{|p| product_list.product_list_products.where(product_id: p.id).delete_all }
      end
    taxon_ids
  end

  private

  def query_for_taxon_prices(which_currency = nil)
    q = Spree::TaxonPrice.where(taxon_id: id)
    q = q.where(currency: which_currency) if which_currency.present?
    q
  end
end

::Spree::Taxon.prepend Spree::TaxonDecorator if ::Spree::Taxon.included_modules.exclude?(Spree::TaxonDecorator)