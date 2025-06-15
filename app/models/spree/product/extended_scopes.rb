##
# Avoid overriding gem's existing Spree::ProductScopes
module Spree::Product::ExtendedScopes
  extend ActiveSupport::Concern

  included do
    attr_accessor :has_sorting_rank_changes, :uploaded_images, :image_alts, :image_viewable_ids, :currency, :price_attributes, :master_option_value_ids, :user_variant_option_value_ids


    belongs_to :retail_site, class_name:'Retail::Site', foreign_key: :retail_site_id

    belongs_to :master_product, -> { with_deleted }, class_name: 'Spree::Product', foreign_key: :master_product_id 
    has_many :slave_products, -> { with_deleted }, class_name: 'Spree::Product', foreign_key: :master_product_id
    has_one :product_list_product

    # Variants
    belongs_to :rep_variant, class_name:'Spree::Variant', foreign_key: :rep_variant_id
    belongs_to :best_variant, class_name:'Spree::Variant', foreign_key: :best_variant_id
    

    # Admin reviews
    has_one :record_review, -> { where(record_type:'Spree::Product') }, foreign_key: :record_id, class_name: 'Spree::RecordReview'

    # Buyer reviews
    has_many :reviews, dependent: :delete_all

    has_many :scraper_page_imports, class_name:'Spree::ScraperPageImport', foreign_key:'spree_product_id', dependent: :delete_all, inverse_of: :spree_product
    has_many :scraper_pages, class_name:'Scraper::Page', through: :scraper_page_imports

    with_options inverse_of: :product, class_name:'Spree::Variant' do
      # Optimized w/o default 'order by position'
      has_many :variants_without_order, -> { joins(:product).unscoped.where(is_master: false) }
      has_many :variants_including_master_without_order, -> { joins(:product).unscoped }

      ##
      # Either the creator of product or phantom seller
      has_many :sample_variants, 
        -> { joins(:product).joins(:user => :role_users).distinct(Spree::Variant.table_name + '.id').
            where("#{Spree::Product.table_name}.user_id=#{Spree::Variant.table_name}.user_id OR #{Spree::RoleUser.table_name}.role_id IN (?)", [Spree::Role.phantom_seller_role.id] ) }

      has_many :original_variants, 
        -> { joins(:product).where(is_master: false).where("#{Spree::Variant.table_name}.user_id IS NULL OR #{Spree::Product.table_name}.user_id = #{Spree::Variant.table_name}.user_id") }
      
      has_many :original_variants_including_master, 
        -> { joins(:product).where("#{Spree::Variant.table_name}.user_id IS NULL OR #{Spree::Product.table_name}.user_id = #{Spree::Variant.table_name}.user_id") }

      has_many :not_adopted_variants_including_master, 
        -> { joins(:product).where("is_master=false AND #{Spree::Variant.table_name}.user_id IS NOT NULL") }

      has_many :adopted_variants, 
        -> { joins(:product).where("is_master=false AND #{Spree::Variant.table_name}.user_id IS NOT NULL AND (#{Spree::Product.table_name}.user_id IS NULL OR #{Spree::Product.table_name}.user_id != #{Spree::Variant.table_name}.user_id)") }
    end

    has_many :line_items
    has_many :associated_completed_orders, 
      -> { where("#{Spree::Order.table_name}.state='complete'").order("#{Spree::Order.table_name}.completed_at DESC") }, 
      through: :line_items, class_name:'Spree::Order', source: 'order'

    # Scopes
    scope :not_reviewed, -> { where('last_review_at IS NULL') }
    scope :reviewed, -> { where('last_review_at IS NOT NULL') }
    scope :with_acceptable_status, -> { where("#{Spree::Product.table_name}.iqs > 0") }

    scope :search_indexable, -> { joins("LEFT JOIN spree_products b on spree_products.id = b.master_product_id").where("#{Spree::Product.table_name}.iqs > 5 AND b.id IS NULL") }
    scope :includes_for_indexing, -> { includes(:taxons, :option_types, master: [:default_price], variants_including_master_without_order: [:option_value_variants] ) }
    scope :includes_for_search, -> { includes(:variants, { master: :images }, :option_types, :taxons) }

    scope :order_for_review, -> { left_joins(:user).order("#{Spree::User.table_name}.seller_rank desc, #{Spree::Product.table_name}.user_id asc") }
    
    # Call proper joins, either :variants or :variants_including_master
    scope :having_adoptions, -> { left_joins(:variants_including_master_without_order => :variant_adoptions).where("#{Spree::VariantAdoption.table_name}.user_id != #{Spree::Product.table_name}.user_id").distinct("#{Spree::Product.table_name}.id") }

    scope :from_retail_sites, -> { where('retail_site_id IS NOT NULL AND retail_site_id != ?', Retail::Site.find_by(name:'ioffer')&.id ) }
    scope :not_from_retail_sites, -> { where('retail_site_id IS NULL OR retail_site_id = ?', Retail::Site.find_by(name:'ioffer')&.id ) }

    def variants_for_user(user)
      @variants_for_user_map ||= {}
      user_variants = @variants_for_user_map[user.id]
      return user_variants if user_variants
      if user.admin?
        user_variants = variants_without_order
      else
        user_variants = variants_without_order.where(user_id: user.id)
      end
      @variants_for_user_map[user.id] = user_variants
      user_variants
    end

    def variants_including_master_for_user(user)
      if user.admin?
        variants_including_master
      else
        variants_including_master.where('user_id IS NULL OR user_id=?', user.id)
      end
    end

    ##
    # Instead of product.variant_images, this filters down to user's accessible images.
    def variant_images_for_user(user)
      if user.admin?
        variant_images
      elsif user_id && user_id == user.id
        variant_ids = variants_including_master_for_user(user).select('id').collect(&:id)
        Spree::Image.where(viewable_type:'Spree::Variant', viewable_id: variant_ids).order('position ASC')
      else
        variant_ids = variants_for_user(user).select('id').collect(&:id)
        Spree::Image.where(viewable_type:'Spree::Variant', viewable_id: variant_ids).order('position ASC')
      end
    end

    def display_variant_adoption
      display_variant_adoption_code.blank? ? nil :
        Spree::VariantAdoption.with_deleted.find_by(code: display_variant_adoption_code)
    end

  end
end