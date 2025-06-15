##
# Simulate the way Spree::Taxon category hierarchy.  But each site has its own root.
# Attributes: site_name, other_site_category_id, mapped_taxon_id, parent_id, position, name, lft, rgt, depth
class Retail::SiteCategory < ApplicationRecord

  self.table_name = 'retail_site_categories'

  acts_as_nested_set

  attr_accessor :is_new

  belongs_to :retail_site, class_name: 'Retail::Site', foreign_key: :retail_site_id
  belongs_to :mapped_taxon, class_name: 'Spree::Taxon', optional: true
  alias_method :taxon, :mapped_taxon
  scope :mapped, ->{ where('mapped_taxon_id IS NOT NULL') }

  validates :site_name, presence: true
  validates :name, presence: true

  before_save :set_other_attributes
  after_save :touch_ancestors_and_taxonomy
  after_touch :touch_ancestors_and_taxonomy

  def categories_in_full_path
    unless @categories_in_full_path
      @categories_in_full_path = [self]
      current = self
      while current.parent && current.parent.depth > 0
        @categories_in_full_path.insert(0, current.parent)
        current = current.parent
      end
    end
    @categories_in_full_path
  end

  def full_path
    categories_in_full_path.collect(&:name).join(' > ')
  end

  ##
  # Iterate upwards to parents find mapped_taxon
  def deepest_mapped_taxon
    deepest = mapped_taxon
    current = self
    while (deepest.nil? && current.parent && current.depth > 0)
      current = current.parent
      deepest = current.mapped_taxon
    end
    deepest
  end

  ###################################
  # Class methods

  ##
  # Since SiteCategory originally only stored site_name, which requires consistency in format of name,
  # this generates safely the DB query to use retail_site_id if integer else site_name.
  # @return [Hash]
  def self.query_condition_for(site_name_or_integer, other_query_conditions = {})
    if site_name_or_integer.is_a?(Integer)
      other_query_conditions.merge(retail_site_id: site_name_or_integer)
    else
      other_query_conditions.merge(site_name: site_name_or_integer)
    end
  end

  def self.root_for(site_name_or_integer)
    site = ::Retail::Site.find_site_by_name_or_id(site_name_or_integer)
    scat = self.find_or_initialize_by(query_condition_for(site_name_or_integer, parent_id: nil) ) do |cat|
      cat.site_name = site.try(:name)
      cat.retail_site_id = site.try(:id)
      cat.name = "#{site.try(:name) || site_name_or_integer} categories"
    end
    scat.save
    scat
  end

  # @return SiteCategory
  def self.find_by_full_path(site_name_or_integer, full_path)
    levels = full_path.is_a?(Array) ? full_path : full_path.split(' > ')
    taxon = nil
    current_node = root_for(site_name_or_integer)
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

  ##
  # @return [Array of SiteCategory]
  def self.find_or_create_this_category_path(category_names, site_name_or_integer)
    categories_in_path = []
    site = ::Retail::Site.find_site_by_name_or_id(site_name_or_integer)
    category_names.each do|cat_name|
      next if cat_name.blank?
      parent_category = (categories_in_path.last || root_for(site_name_or_integer) )
      cur_category = parent_category.children.find{|child| child.name.downcase == cat_name.downcase }
      unless cur_category
        cur_category ||= ::Retail::SiteCategory.create( name: cat_name, retail_site_id: site.id, site_name: site.name)
        cur_category.move_to_child_of( parent_category )
      end
      categories_in_path << cur_category
    end
    categories_in_path
  end

  ##
  # @return <Array of SiteCategory>
  def self.find_or_create_for(other_site_category, verbose = false)
    taxons = []
    current_node = root_for(other_site_category.retail_site_id || other_site_category.site_name)
    other_site_category.retail_site_id ||= ::Retail::Site.find_site_by_name_or_id(other_site_category.retail_site_id || other_site_category.site_name).try(:id)
    other_site_category.full_path.split(' > ').each_with_index do |cat_name, level_index|
      t = current_node.children.where(name: cat_name).first
      spree_taxon = other_site_category.category_id ? other_site_category.category.category_taxon : nil

      if t.nil?
        t = self.create(site_name: other_site_category.site_name, retail_site_id: other_site_category.retail_site_id,
                        other_site_category_id: other_site_category.other_site_category_id,
                        name: cat_name,
                        mapped_taxon_id: spree_taxon.try(:id))
        t.is_new = true
        t.move_to_child_of(current_node)
      end
      if t.is_new || verbose
        indent = '.' * (level_index * 25)
        puts '%-80s | %60s (%4d) | %s' %
                 [indent + cat_name, spree_taxon.try(:permalink).to_s, spree_taxon.try(:id).to_i, t.is_new ? '***' : '']
      end
      taxons << t
      current_node = t
    end
    taxons
  end


  private

  def touch_ancestors_and_taxonomy
    # Touches all ancestors at once to avoid recursive taxonomy touch, and reduce queries.
    self.class.where(id: ancestors.pluck(:id)).update_all(updated_at: Time.current)
  end

  def set_other_attributes
    if site_name.blank? && retail_site_id
      self.site_name = ::Retail::Site.find_by_id(retail_site_id).try(:name)
    end
    if retail_site_id.nil? && site_name.present?
      self.retail_site_id = ::Retail::Site.find_by_name(site_name).try(:id)
    end
  end
end