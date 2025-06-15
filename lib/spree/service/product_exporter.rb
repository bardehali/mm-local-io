# product_exporter, products exporter, product exporter, export products

module Spree
  module Service
    class ProductExporter

      def initialize(query, options = {})
        @query = query
        @verbose = options[:verbose]
      end

      def headers
        ['Item ID', 'Title', 'Description', 'Brands', 'Retail Source', 'Category', 'Category ID',
          'Original Poster ID', 'Original Poster Username', 'Original Poster Role',
          'IQS', 'View Count', 'TRX Count', 'Cart Count', 'Reviews Count', 'Last Adoption At',
          'Viable Adopters Now', 'Potential Adopters',
          'Category Floor Price', 'Original Listing Price', 'Display Price',
          'Current Seller ID', 'Current Seller Username', 'Current Seller Last Active Ago (days)', 'Current Seller Last Active Date', 'Current Seller Role',
          'Last Trx Price', '# Days Ago', 'Last TRX Seller ID', 'Last TRX Seller Username', 'Last TRX Seller Role', 'Number of Colors', 'Number of Sizes', 'Total Number of Variants',
          'Number of Images', 'Data Number', 'Thumbnail URL', 'Full Size Image URL'
         ]
      end

      def export_to(io)
        headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
        io.write(headers_row)
        iterate do|p|
          row_values = make_row_values(p)

          puts "=========================================\n#{row_values}" if @verbose
          row = CSV::Row.new(headers, row_values)
          io.write(row)
        end
      end

      ##
      # @prepending [Array] for every row of values, put these before of model's values
      # @appending [Array] for every row of values, put these after of model's values
      def to_csv(prepending = [], appending = [])
        CSV.generate(headers: true) do |csv|
          csv << headers

          iterate do |p|
            row_values = prepending || []
            row_values += make_row_values(p)
            row_values += appending if appending
            csv << row_values
          end
        end
      end

      def make_row_values(p)
        row_values = [p.id, p.name, p.description, p.brands.collect(&:presentation).join(', '), p.retail_site&.name]
        row_values += [p.taxons.first&.breadcrumb, p.taxons.first&.id, p.user&.id, p.user&.username, p.user&.spree_roles.to_a.collect(&:short_name).join(', ') ]
        row_values += [p.iqs, p.view_count, p.calculate_transaction_count, Spree::Order.where(state:'cart').with_product_id(p.id).count ]
        row_values += [p.reviews.count]

        all_variants = p.variants_including_master_without_order.includes(:option_values => [:option_type]).where(converted_to_variant_adoption: false).spree_base_scopes.active('USD')
        option_types = Spree::Variants::OptionTypesFinder.new(variant_ids: all_variants.map(&:id)).execute
        viable_variant_ids = p.variants_including_master_without_order.includes(:option_values).find_all{|v| option_types.blank? || (v.option_values.collect(&:option_type_id).sort & option_types.collect(&:id).sort ).size > 0 }.collect(&:id)
        viable_adoptions_q = Spree::VariantAdoption.joins(:user).where("variant_id IN (?) and seller_rank >= ?", viable_variant_ids, Spree::User::BASE_PENDING_SELLER_RANK )

        adoptions_q = Spree::VariantAdoption.joins(:user).where("variant_id IN (?) and seller_rank >= ?", all_variants.collect(&:id), Spree::User::BASE_PENDING_SELLER_RANK )

        row_values << adoptions_q.last&.created_at&.to_mid_s

        row_values << viable_adoptions_q.count("distinct(#{Spree::VariantAdoption.table_name}.user_id)")
        row_values << adoptions_q.count("distinct(#{Spree::VariantAdoption.table_name}.user_id)")

        row_values += [ taxon_floor_prices_map[p.taxons.first&.id]&.price, p.price&.to_f ]

        best_record = p.best_price_record
        row_values += [ p.best_price_record&.price, best_record.user&.id, best_record.user&.username, best_record.user&.last_active_at.relatively_days_ago, best_record.user&.last_active_at, best_record&.user&.spree_roles.to_a.collect(&:short_name).join(', ') ]

        last_o = p.last_completed_order
        row_values += [last_o&.line_item_of_product(p.id)&.price&.to_f ]
        row_values += [last_o ? ((Time.now - last_o.completed_at) / 1.day).to_i : '' ]
        row_values += [last_o&.seller&.id, last_o&.seller&.username, last_o&.seller&.spree_roles.to_a.collect(&:short_name).join(', ') ]

        colors_set = Set.new
        sizes_set = Set.new
        all_variants.each do|v|
          v.option_values.each do|ov|
            if ov.option_type.color?
              colors_set << ov.id
            elsif ov.option_type.size?
              sizes_set << ov.id
            end
          end
        end
        row_values << colors_set.size
        row_values << sizes_set.size

        row_values << all_variants.size

        row_values << p.variant_images.count

        row_values << p.data_number

        img = p.variant_images.first

        if p.variant_images.count > 0
          #row_values << (img ? cdn_image_url( img, :pdp_thumbnail ) : "")
          #row_values << (img ? cdn_image_url( img, :pdp_thumbnail ) : "")

          row_values << ActiveStorage::Blob.service.url(p.variant_images.first.url(:pdp_thumbnail).key).split('?').first.gsub('http:', 'https:')
          row_values << ActiveStorage::Blob.service.url(p.variant_images.first.attachment.key).split('?').first.gsub('http:', 'https:')
        else
          #row_values << nil
        end

        row_values
      end

      protected

      def iterate
        @query.in_batches(of: 100) do|subq|
          subq.includes(:retail_site, :taxons, :user, variants_including_master_without_order:[:option_values, :default_price] ).each do|p|
            yield p if block_given?
            next if p.skip_export
          end
        end
      end

      ##
      # Cache
      def taxon_floor_prices_map
        unless @taxon_floor_prices_map
          @taxon_floor_prices_map = Spree::TaxonPrice.all.group_by(&:taxon_id)
          @taxon_floor_prices_map.each_pair do|k,v|
            @taxon_floor_prices_map[k] = v.sort_by(&:price).first
          end
        end
        @taxon_floor_prices_map
      end
    end
  end
end
