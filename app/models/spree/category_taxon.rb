module Spree
  class CategoryTaxon < Taxon

    TOP_LEVEL_CATEGORIES_CACHE_KEY = 'Spree::CategoryTaxon.top_level_categories.' + Rails.env

   
    after_save :clear_cache

    def self.root
      Rails.cache.fetch('categories_root') do
        self.where(name: 'Categories', parent_id: nil).includes(:children).last
      end
    end

    def self.no_category
      Rails.cache.fetch('categories_no_category') do
        t = self.where(name: 'No Category').last
        unless t
          t = Spree::Taxon.create(name:"No Category", 
            meta_title:"Other Category", taxonomy_id: Spree::Taxonomy.categories_taxonomy.id)
        end
        t
      end
    end

    ##
    # Find deepest category according to given +full_path+.
    # @return <Spree::Taxon>
    def self.find_by_full_path(full_path)
      levels = full_path.is_a?(Array) ? full_path : full_path.split(' > ')
      taxon = nil
      current_node = root
      levels.each do |cat_name|
        t = current_node.children.where(name: cat_name).first
        if t.nil?
          break
        else
          taxon = t
          current_node = t
        end
      end
      taxon
    end

    def self.find_or_create_categories_taxon()
      taxon = root
      taxon ||= find_or_create_by!(taxonomy_id: find_or_create_categories_taxonomy.id) do|t|
        t.position = 0
        t.name = 'Categories'
        t.permalink = 'categories'
      end
      taxon
    end

    def self.find_or_create_categories_taxonomy()
      taxonomy = ::Spree::Taxonomy.find_or_create_by(name: 'Categories') do|t|
        t.position = 1
      end
      taxonomy.root ||= Spree::Taxon.create!(taxonomy_id: taxonomy.id, name: 'Categories')
      taxonomy
    end

    def self.find_or_create_this_category_path(category_names)
      categories_in_path = []
      category_names.each do|cat_name|
        next if cat_name.blank?
        parent_category = (categories_in_path.last || root)
        cur_category = parent_category.children.find{|child| child.name.downcase == cat_name.downcase }
        unless cur_category
          cur_category ||= ::Spree::Taxon.create(
              name: cat_name,
              permalink: (categories_in_path.last ?
                  categories_in_path.last.permalink + "/#{cat_name.downcase}"
              : "categories/#{cat_name.downcase}"),
              taxonomy_id: ::Spree::Taxonomy.categories_taxonomy.id )
          cur_category.move_to_child_of( parent_category )
        end
        categories_in_path << cur_category
      end
      categories_in_path
    end

    ##
    # Cached top level (depth=1) categories.
    def self.top_level_categories
      Rails.cache.fetch(TOP_LEVEL_CATEGORIES_CACHE_KEY, expires_in: Rails.env.production? ? 12.hours : 1.minute) do
        root.children
      end
    end

    ##
    # 
    def self.most_product_top_categories
      joins(:product_count_stat).includes(:product_count_stat).where(id: top_level_categories.collect(&:id) ).order('record_count desc')
    end
    
    ##
    # @yield Spree::Taxon, count (Integer)
    def self.save_product_counts(&block)
      root.descendants.each do|t| 
        cnt = Spree::Classification.where(taxon_id: t.self_and_descendants.collect(&:id) ).count;
        stat = Spree::RecordStat.find_or_initialize_by(
          record_type: 'Spree::Classification', record_column: 'taxon_id', record_id: t.id)
        stat.record_count = cnt
        stat.save
        yield t, cnt if block_given?
      end
    end

    protected

    def clear_cache
      Rails.cache.delete(TOP_LEVEL_CATEGORIES_CACHE_KEY)
    end
  end
end