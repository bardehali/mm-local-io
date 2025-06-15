##
#
module Spree
  module Service
    module ProductsTaskHelper
      extend ActiveSupport::Concern

      ####################################
      # Methods

      ##
      # First try to fetch a portion of option value combos from variants already created.
      # If empty, would go through product's taxons' related_option_types, and pick a limited portion 
      # of their option_values and create N1 x N2 matrix table of combos.
      # @return [Array of Array of Spree::OptionValue]
      def pick_option_value_combos(product)
        option_value_combos = []
        brand_id = Spree::OptionType.brand.id
        product.variants_including_master.each do|variant|
          combo_found = variant.option_values.reject{|ov| variant.is_master && ov.option_type_id == brand_id }
          option_value_combos << combo_found if combo_found.size > 0
        end
        option_value_combos.uniq!
        combos = option_value_combos.shuffle[0, ((option_value_combos.size.to_f / 2).round + rand(option_value_combos.size / 2)) ]
        if combos.size == 0
          product.taxons.each do|taxon|
            # N1 x N2 population
            selected_option_type_values = []
            taxon.closest_related_option_types.each do|option_type|
              next if option_type.name =~ /\Abrands?\Z/i || selected_option_type_values.size >= 2
              selected_option_type_values << option_type.option_values.limit( 1 + rand(3) ).all
            end
            selected_option_type_values[0].to_a.each do|first_option_value|
              if selected_option_type_values.size > 1
                selected_option_type_values[1].each do|second_option_value|
                  combos << [first_option_value, second_option_value]
                end
              else
                combos << [first_option_value]
              end
            end
          end
        end
        combos.uniq!
        combos
      end

      ##
      # Minimize product categories to one.
      # Replace option types w/ updated related option types; delete variant if option type removed.
      # This does clear out elasticsearch-model model._commit_callbacks to skip continuous 
      # calls to update product in search index.
      def cleanup_option_value_combos(product, dry_run = true)
        product._commit_callbacks.clear # skip ES update

        existing_option_type_ids = product.product_option_types.collect(&:option_type_id)
        taxon = select_best_taxon_for(product)
        puts '#' * 40
        puts '%7d | %s' % [product.id, product.name]

        brand_ot = Spree::OptionType.brand
        if taxon.nil?
          puts '    no category'
          return
        else
          puts '  in %s => %s' % [taxon.breadcrumb, taxon.option_types.collect(&:presentation).join(' | ')]
        end
        updated_option_types = taxon.closest_related_option_types
        updated_option_type_ids = updated_option_types.collect(&:id).uniq
        
        unless dry_run
          product.classifications.where("taxon_id != #{taxon.id}").delete_all
          updated_option_types.each{|ot| product.product_option_types.find_or_create_by(option_type_id: ot.id) }
        end

        # Delete
        puts '    Variants to delete:'
        product.variants_including_master.each do|v|
          v_option_type_ids = v.option_values.collect(&:option_type_id) - [brand_ot.id]
          option_ids_to_delete = updated_option_type_ids - v_option_type_ids
          next if option_ids_to_delete.empty?

          if v.is_master
            puts '    - master from %s: $%.2f | %s' % [v.user&.login, v.price.to_f, v.sku_and_options_text]
            unless dry_run
              v.option_value_variants.joins(:option_value).where("option_type_id IN (?)", option_ids_to_delete ).delete_all
            end
          else
            if option_ids_to_delete.present?
              puts '    - (%d) from %s: $%.2f | %s' % [v.id, v.user&.login, v.price.to_f, v.sku_and_options_text]
              # v.destroy would not work if in cart
              v.destroy || v.update_column(:deleted_at, Time.now) unless dry_run
            end
          end
        end

        product.product_option_types.where(option_type_id: [existing_option_type_ids - updated_option_type_ids] ).delete_all unless dry_run

        unless dry_run
          generate_all_fake_option_value_combos(product, updated_option_types)
        end
      rescue Exception => e
        puts "** Problem for product #{product.id}: #{e.message}\n#{e.backtrace.join("\n  ")}"
      end

      ##
      # @s [Integer or String] either Spree::Taxon#id or name or breadcrumb of category
      # @retail_site [Retail::Site]
      def convert_to_taxon(s, retail_site = nil)
        if s.is_a?(Integer) || s =~ /\A\d+\Z/
          Spree::Taxon.find_by(id: s.to_i)
        elsif s.is_a?(String)
          # Spree::Taxonomy.categories_taxonomy.taxons.find_by(name: s)
          retail_site ? retail_site.site_categories.where(name: s).last&.mapped_taxon : Retail::SiteCategory.find_by(name: s)
        else
          nil
        end
      end

      ##
      # @csv_file [String, file name/path] If nil, would be $stdout
      def export_products_to_csv(query, csv_file = nil)
        verbose = (ENV['VERBOSE'].to_s == 'true')
        File.delete(csv_file) if File.exists?(csv_file)

        io = csv_file.present? ? File.open(csv_file, 'w') : $stdout
        Spree::Service::ProductExporter.new(query, verbose: verbose).export_to(io)

        io.close if io.is_a?(File)
      end

      ##
      # Generate all instances of combos of option values of product's related option types.
      # Each combo would be within a variant created by admin if no match found.
      def generate_all_fake_option_value_combos(product, option_types = nil)
        taxon = product.taxons.first
        option_types ||= taxon.closest_related_option_types
        variants = product.variants.includes(:option_value_variants).to_a # offline instead of constantly refreshing
        new_variant_attr = { product_id: product.id, user_id: Spree::User.fetch_admin.id, 
          price: product.price.to_f > 200 ? 99 : product.price.to_f }
        lists = option_types.collect(&:option_values_for_auto_run)
        
        add_more_to_combo(nil, *lists) do|combo|
          next if combo.nil?
          # puts combo.collect{|ov| "#{ov.option_type.name}: #{ov.presentation}" }.join(' | ')
          v = variants.find do|v|
            v.option_value_variants.collect(&:option_value_id).sort == combo.collect(&:id).sort
          end
          unless v
            v = Spree::Variant.create(new_variant_attr)
            combo.each{|ov| Spree::OptionValueVariant.create(variant_id: v.id, option_value_id: ov.id) }
          end
        end
      end

      def add_more_to_combo(combo = [], *lists, &block)
        list = lists.pop
        if list
          list.each do|a|
            combo ||= []
            add_more_to_combo( combo + [a], *lists, &block )
          end
        else
          yield combo
        end
      end

      ##
      # Certain retail sites could need to prefer certain category over multiple.
      def select_best_taxon_for(product)
        taxons = product.taxons.includes(:related_option_types).order('position asc').all
        if %w(perfectkickz chanzsneakers).include?(product.retail_site&.name&.downcase)
          r = /\bmen\'?s\b/i
          taxons.find{|t| t.name =~ r || t.breadcrumb =~ r } || taxons.first
        else
          taxons.first
        end
      end


      def build_products_query_from_arguments
        plist = ENV['PRODUCT_LIST_NAME'].present? ? Spree::ProductList.find_by(name: ENV['PRODUCT_LIST_NAME']) : nil
        plist ||= ENV['PRODUCT_LIST_ID'].present? ? Spree::ProductList.find_by(id: ENV['PRODUCT_LIST_ID'].to_i) : nil
        query = plist ? plist.products : Spree::Product.where("user_id is not null")
        query = apply_more_to_query(query)
        puts "Query: #{query.to_sql}"
        puts 'Total %d products' % [query.count]
        query
      end

      def url_for_product(product)
        if Rails.env.development?
          "http://localhost/products/#{product.id}"
        else
          "https://www.ioffer.com/products/#{product.id}"
        end
      end

    end
  end
end