module Spree::Product::Importer
  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods

    ##
    # Hash should have keys in string as expected to be from JSON parse.
    # @product_h
    #   required keys: :title, :description, :photos
    #   optional keys:
    #     scraper_page_id - given would create Spree::ScraperPageImport

    def create_from_hash(product_h, retail_site)
      product = nil
      store_user = find_or_create_store_and_user(product_h, retail_site.id)

      scraper_page_import = nil
      if (scraper_page_id = product_h['scraper_page_id'] )
        scraper_page_import = ::Spree::ScraperPageImport.where(scraper_page_id: scraper_page_id).joins(:spree_product).first
      end

      product ||= ::Spree::Product.create(
          name: product_h['title'] || product_h['name'],
          description: product_h['description'],
          shipping_category_id: ::Spree::ShippingCategory.default.try(:id),
          price: product_h['price'],
          retail_site_id: retail_site.id,
          user_id: store_user.id
        )

      return nil if product.nil? || !product.valid?
      if scraper_page_id && scraper_page_import.nil?
        ::Spree::ScraperPageImport.create(scraper_page_id: scraper_page_id, spree_product_id: product.id) 
      end

      # add main photos
      product_h['photos'].to_a.uniq.each do|image_url|
        image_url = retail_site.abs_url(image_url) if image_url.start_with?('/')
        open(image_url) do|image|
          spree_image = Spree::Image.create(attachment:{ io: image, filename: image_url.split('/').last }, viewable: product.find_or_build_master)
        end
      end
      variant_index = 1
      (product_h['properties'] || {} ).each_pair do|prop_name, prop_values|
        prop_values.to_a.each do|prop_h|
          prop_name_fixed = prop_name.downcase.split(/\W+/)[0,2].join(' ')
          option_type = ::Spree::OptionType.find_or_create_by(presentation: prop_name_fixed) do|r|
            r.presentation = prop_name_fixed
          end
          prop_value = prop_h['value']
          option_value = nil
          if prop_value.present? && option_type.id
            option_value = option_type.option_values.find_or_create_by(presentation: prop_value.strip) do|r|
              r.name = prop_value.downcase
              r.user_id = store_user.try(:id)
            end
          end
          product.product_option_types.find_or_create_by(option_type_id: option_type.id) if option_value

          if (image_url = prop_h['image'] ).present?
            image_url = retail_site.abs_url(image_url) if image_url.start_with?('/')
            if option_value
              variant = product.variants.create(position: variant_index)
              ::Spree::OptionValueVariant.create(variant_id: variant.id, option_value_id: option_value.id)
              open(image_url) do|image|
                spree_image = Spree::Image.create(attachment:{ io: image, filename: image_url.split('/').last }, viewable: variant)
              end
              variant_index += 1
  
            else
              open(image_url) do|image|
                spree_image = Spree::Image.create(attachment:{ io: image, filename: image_url.split('/').last }, viewable: product.find_or_build_master)
              end
            end
          end
        end # each prop_value_h
        
      end # each property

      product.set_category_taxon(product_h)

      product

    rescue Exception => product_e
      logger.warn "** Problem converting entry of #{product_h['title'] || product_h} from page #{product_h['page_url']}:\n  #{product_e.message}\n  #{product_e.backtrace.join("  \n")}"
      product
    end

    # Changed version of Spree::ProductDuplicator#duplicate
    def build_clone(&block)
      draft = self.dup.tap do |new_product|
        # new_product.taxons = self.taxons
        new_product.created_at = nil
        new_product.deleted_at = nil
        new_product.updated_at = nil
        new_product.product_properties = self.reset_properties
        # new_product.master = duplicate_master
        new_product.price = self.price
        new_product.sku = '' # "COPY OF #{self.sku}" if self.sku.present? && !self.sku.start_with?('COPY OF ')
      end

      draft.option_types = self.option_types
      draft.master_product_id = self.master_product_id || self.id

      yield draft if block_given?

      draft.find_or_build_master
      draft.copy_taxons_from(self)

      draft
    end

    def copy_taxons_from(other_product)
      other_product.classifications.includes(:taxon).each do|c|
        new_c = ::Spree::Classification.new(product_id: self.id, taxon_id: c.taxon_id, position: c.position)
        self.classifications << new_c
        # self.taxons << c.taxon if c.taxon # immediate ref
      end
    end

    def copy_variants_from!(other_product)
      other_product.variants_including_master.each do|v|
        v.option_values.each do|option_value|
          if v.is_master
            new_ovv = ::Spree::OptionValueVariant.find_or_create_by(variant_id: self.master.id, option_value_id: option_value.id)
            self.master.option_value_variants.reload
            new_ovv
          else
            self.variants.create(option_value_ids: [option_value.id], price: master.price)
          end
        end
      end
    end

    ##
    # Copying images from master_product.
    def copy_from_master!
      if master_product_id && master_product
        master_variant = find_or_build_master
        master_product.images.each do|image|
          new_image = image.dup
          new_image.assign_attributes(attachment: image.attachment.clone)
          new_image.viewable_type = 'Spree::Variant'
          new_image.viewable_id = master_variant.id
          new_image.save
        end
      end
    end

    ##
    # Steps: find or create Retail::Store w/ that retail_site_store_id.
    # @return [Spree::User]
    def find_or_create_store_and_user(product_h, retail_site_id = nil)
      store_h = product_h['store']
      store = nil
      if (store_h && store_h['retail_site_store_id'].present? )
        store = Retail::Store.where(retail_site_id: product_h['retail_site_id'] || retail_site_id, retail_site_store_id: store_h['retail_site_store_id'] ).last
        store ||= Retail::Store.create( 
          store_h.merge(retail_site_id: product_h['retail_site_id'] || retail_site_id) )
        store_user = store.setup_spree_user_and_store!
      end
      store_user ||= Spree::User.fetch_admin
      store_user
    end

  end
end