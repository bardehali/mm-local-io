require 'csv'
require 'open-uri'
require 'mechanize'
require File.join(Rails.root, 'lib/tasks/task_helper')
require File.join(Rails.root, 'lib/tasks/server_helper')
require File.join(Rails.root, 'lib/spree/service/product_exporter')
require File.join(Rails.root, 'lib/spree/service/products_task_helper')
include ::TaskHelper
include ::ServerHelper
include ::Spree::Service::ProductsTaskHelper

####################################
# Tasks

namespace :products do

  ##
  # Fields can be:
  #   Without header, would be name,description,image_url
  # Useable environment variables:
  #   RETAIL_SITE [name of site] if present would find or create the site and associate products to this
  #   DRY_RUN [string true/false]
  #   IMAGES_PREDOWNLOADED [string top level directory]
  #   ROWS [String, delimited by ','] row index number starting w/ 0
  #   PRODUCT_LIST_NAME [String]
  #
  # Required arguments:
  #   1. CSV file
  # Syntax like: bundle exec rake products:import_from_csv "/data/inactive_sellers.csv"
  task :import_from_csv => [:environment] do
    ARGV.shift
    csv_file = ARGV.shift
    trap_signal_and_exit
    convert_env_variables
    print_beginning_info

    puts "CSV file: #{csv_file}"

    seller = Spree::User.pick_phantom_sellers(1, 0).first
    brand = Spree::OptionType.brand || Spree::OptionType.create(name:'brand', description:'Brand')
    puts "for user: #{seller.to_s}"

    retail_site_name = ENV['RETAIL_SITE']
    retail_site = retail_site_name.present? ? Retail::Site.find_or_create_by_name(retail_site_name) : nil
    puts '=' * 60

    IMAGES_DIRECTORY = ENV['IMAGES_DIRECTORY']
    puts "Images Directory #{IMAGES_DIRECTORY&.strip}"

    DRY_RUN = @dry_run

    LIMIT = ENV['LIMIT']
    ROW_INDICES = ENV['ROWS'].to_s.split(',').collect(&:to_i)
    valid_count = 0
    invalid_rows = []

    OFFSET = ENV['OFFSET']

    puts "Images in /#{IMAGES_DIRECTORY}"
    puts "limit? #{LIMIT}"
    puts "rows (starts w/ 0)? #{ROW_INDICES}"

    plist = Spree::ProductList.find_or_create_by(name: ENV['PRODUCT_LIST_NAME'].strip) if ENV['PRODUCT_LIST_NAME']&.strip.present?

    # For checking possible stripped out brand from name of product
    brand = Spree::OptionType.brand
    existing_brands = Set.new # downcase string
    if plist
      plist.products.includes(master:[:option_values] ).each do|p|
        p.master.option_values.each{|ov| existing_brands << ov.presentation.downcase if ov.option_type_id == brand.id }
      end
      existing_brands = existing_brands.collect{|b| /\b(#{b.gsub(/(\s+)/,'\s+') })\b/i }
      puts "Product list already has #{existing_brands.size} brands"
    end

    check_duplicates = ( ENV['CHECK_DUPLICATES'].to_s == 'true' )
    last_name = ''
    last_image_url = ''
    total_images_requested = 0
    total_images_saved = 0
    wrong_products = {}
    missing_rows = []
    csv_file_dirname = File.dirname(csv_file)
    CSV.parse(File.read(csv_file), headers: true).each_with_index do |csv_row, row_index|
      # puts "#{row_index} -----------------" if row_index % 100 == 0
      if ROW_INDICES.present?
        if ROW_INDICES.include?(row_index)
          # puts "Row #{row_index}"
        else
          next
        end
      end
      if OFFSET && row_index < OFFSET.to_i
        next
      end

      original_name = csv_row['Title']
      stripped_name = original_name.clone
      if check_duplicates
        # existing_brands.each{|r| stripped_name.gsub!(r, '') }
        # stripped_name.strip!
        if last_name == original_name && last_image_url == csv_row['image1']
          puts '%4d | duplicate of last %s' % [row_index, last_name]
          next
        end
      end
      brand_names = [csv_row['Brand 1'], csv_row['Brand 2'], csv_row['Brand 3']].reject(&:blank?)
      price = csv_row['Price'] || csv_row['Prices']
      taxon = csv_row['Taxon'] || csv_row['Category']
      image_urls = []
      1.upto(10).each do|image_index|
        if (image_url = csv_row["image#{image_index}"]).present?
          image_urls << image_url
        end
      end

      product = nil

      if check_duplicates
        # name, price, categories sorted, and either brands sorted or image names sorted
        q = plist.products.where(name: [original_name, stripped_name] ).includes(:taxons, master:[:default_price, :option_value_variants, :images] )
        # puts q.to_sql
        same_name_products = q.all.to_a
        same_name_products.delete_if do|_p|
          # puts '  VS %9d | %60s | %6.2f | %20s | %s' % [_p.id, _p.name[0,60], _p.price, _p.taxons.collect{|t| t.id.to_s }.sort.join(', '), _p.brands.collect(&:presentation).join(', ')]
          [taxon.to_i ] != _p.taxons.collect(&:id).sort || price.to_f != _p.price
        end
        same_name_products.delete_if do|_p|
          ( brand_names.collect(&:downcase).collect(&:strip).sort & _p.brands.collect(&:presentation).collect(&:downcase).sort ).size < brand_names.size
        end if same_name_products.size > 1
        product = same_name_products.first
      end

      already_created = true
      if product.nil?
        missing_rows << row_index
        puts "#{row_index} " + ('=' * 100)

        already_created = false
        product = Spree::Product.new(name: stripped_name.strip, description: csv_row['Description'] || plist&.name,
          user_id: seller.id, retail_site_id: retail_site&.id,
          shipping_category_id: ::Spree::ShippingCategory.default.try(:id),
          view_count: csv_row['Views'], iqs: csv_row['IQS'], data_number: csv_row['Data Number'], recent_view_count: csv_row['Recent_views'], curation_score: csv_row['Curation']
        )
        product.price = price.to_f
        product.taxons = [ convert_to_taxon(taxon, retail_site) ].compact
        product.taxons << Spree::CategoryTaxon.no_category if product.taxons.blank?
      else
        puts '%4d | found %d, w/ %d brands, %d images saved (%d in CSV)' % [row_index, product.id, product.brands.size, product.master.images.count, image_urls.size, product.recent_view_count] if @debug
      end
      if DRY_RUN
        puts "     %9d | %60s | %6.2f | %20s | %s | valid? %5s\n  %12s | IQS %d, Views %d | %2d images" % [row_index, product.name[0,60], product.price, taxon.to_s, brand_names.join(', '), product.valid?.to_s, product.data_number, product.iqs, product.view_count, image_urls.size] if @debug
      else
        product.save unless DRY_RUN
      end

      if product.id && product.master
        image_urls.each_with_index do|image_url, image_index|
          begin

          subfolder = ""
          if IMAGES_DIRECTORY&.strip.present?
            subfolder = File.join(csv_file_dirname, IMAGES_DIRECTORY)
            puts "Image #{image_index} in #{subfolder}"
          else
            subfolder = File.join(csv_file_dirname, row_index.to_s)
          end

            FileUtils.mkdir_p(subfolder)
            image_name = image_url.split('/').last
            image_file_path = File.join(subfolder, image_name)

            if File.exist?(image_file_path) # use local instead
              if image_file_path.ends_with?('.webp')
                original_path = image_file_path.clone
                image_file_path.gsub!(/(\.webp)\Z/i, '.png')
                WebP.decode(original_path, image_file_path )
              end
              File.open( image_file_path, 'rb') do|image_file|
                spree_image = Spree::Image.create(attachment:{ io: image_file, filename: image_name, content_type: Rack::Mime.mime_type(image_name.split('.').last) }, viewable: product.master)
              end
            else
              fixed_image_url = image_url.gsub(/(\s)/, '%20').gsub('&#x27;', "'")
              open(fixed_image_url) do|image|
                spree_image = Spree::Image.create(attachment:{ io: image, filename: image_name }, viewable: product.master)
              end
              sleep(1 + rand(5) )
            end

          rescue Exception => image_e
            puts "** Problem open image: #{image_e.message} for #{image_url}"
          end
        end if !already_created || product.master&.images&.blank?

        product.product_option_types.find_or_create_by(option_type_id: brand.id) if brand_names.present?
        brand_names.each do|brand_name|
          if brand_name.present?
            if brand_ov1 = brand.option_values.find_or_create_by(presentation: brand_name){|ov| ov.name = brand_name.downcase }
              product.master.option_value_variants.find_or_create_by(option_value_id: brand_ov1.id) unless DRY_RUN
            end
          end
        end

        plist.product_list_products.find_or_create_by(product_id: product.id)

        if ( brand_names.collect(&:downcase).collect(&:strip).sort & product.brands.collect(&:presentation).collect(&:downcase).sort ).size < brand_names.size
          wrong_products[row_index] = [csv_row, product]
        end
      else
        if DRY_RUN && ENV['DOWNLOAD_IMAGES'].present? # download images only
          subfolder = File.join(csv_file_dirname, row_index.to_s)
          FileUtils.mkdir_p(subfolder)
          requested_images = []
          saved_images = []
          image_urls.each_with_index do|image_url, image_index|
            total_images_requested += 1
            requested_images << image_url
            begin
              image_file_path = File.join(subfolder, image_url.split('/').last)
              puts " . Image: #{image_url}"
              if File.exist?(image_file_path)
                file_size = File.new(image_file_path).size
                puts "  -> local exists: #{image_file_path} => size #{file_size}"
                saved_images << image_url if file_size > 0
                next
              end
              # sample not-esacped URL https://images.stockx.com/images/Dior-Saddle-Messenger-Bag-Oblique-Jacquard-Black (1).jpg
              fixed_image_url = image_url.gsub(/(\s)/, '%20').gsub('&#x27;', "'")
              open(fixed_image_url) do|image|
                File.open( image_file_path, 'wb') {|image_file| image_file.write(image.read) }
              end
              saved_images << image_url
            rescue Exception => image_e
              puts "** Problem open image: #{image_e.message} for #{image_url}"
            end
            sleep(1 + rand(5) )
          end # each image
          total_images_saved += saved_images.size
          unless product.valid?
            puts "** Row #{row_index}, Error: #{product.errors.full_messages}"
            puts csv_row
            puts '-' * 60
            invalid_rows << row_index
          end
        end # DRY_RUN
      end
      valid_count += 1 if product.valid?
      break if LIMIT && valid_count >= LIMIT.to_i
      last_name = original_name
      last_image_url = csv_row['image1'] if csv_row['image1'].present?
    end # each row

    print_ending_info
    puts "Total images requested #{total_images_requested} vs saved #{total_images_saved}"
    puts "Rows w/ errors: #{invalid_rows}"
    puts "#{missing_rows.size} rows not found in DB:\n  #{missing_rows}"
    puts "#{wrong_products.size} existing wrong imports"
    wrong_products.each_pair do|k, values|
      p = values.last
      puts "%5d --------------------------\n#{values.first} vs\n  ID %9d | %60s | %s" % [k, p.id, p.name, p.brands.collect(&:presentation).join(', ') ]
    end

  end # task :import_from_csv

  ####################################
  # Export

  desc 'Export imported products from retail sites to CSV with some important attributes'
  task :export_retail_site_products_to_csv => [:environment] do
    trap_signal_and_exit
    ARGV.shift
    csv_file = ARGV.shift
    puts "#{Time.now.to_s} ========================================="
    puts "csv_file? #{csv_file}"

    query = Spree::Product.from_retail_sites
    query = apply_more_to_query(query)

    export_products_to_csv(query, csv_file)
  end

  desc 'Export products without 3rd level categories to CSV'
  task :export_not_specific_category_products_to_csv => [:environment] do
    trap_signal_and_exit
    ARGV.shift
    csv_file = ARGV.shift
    # puts "#{Time.now.to_s} ========================================="

    query = Spree::Product.all
    query = apply_more_to_query(query)

    export_products_to_csv(query, csv_file) do|p|
      p.skip_export = !p.taxons.find{|t| t.depth >= 3 }.nil?
    end
  end


  desc 'Top purchased products; export to CSV'
  task :export_top_purchased_to_csv => [:environment] do
    output = find_or_default_output

    headers = %w(ItemID name price categories view_count IQS purchase_count sellers)
    headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
    output.puts headers_row.to_s

    where_cond = ENV['CUSTOM_WHERE_CONDITION']
    where_cond = "state='complete' and product_id is not null" if where_cond.nil?
    Spree::LineItem.joins(:order => :user).where(where_cond).group(:product_id).order('count_all desc').count.each_pair do|product_id, cnt|
      p = Spree::Product.find(product_id)
      next if p.user_id.nil?

      col_values = [p.id, p.name, p.price.to_s,
        p.taxons.collect(&:breadcrumb).join(' | '), p.view_count, p.iqs, cnt]
      line_items = Spree::LineItem.where(product_id: p.id).includes(:variant => [:user] ).all.reject{|li| li&.variant&.user_id.nil? }
      col_values << line_items.collect{|li| "#{li.variant.user&.email} (#{li.variant.user_id})" }.uniq.join(' | ')

      row = CSV::Row.new(headers, col_values)
      output.puts row.to_s
    end.class

    output.close if output.is_a?(File)
  end


  task :export_imported_items_sold => [:environment] do
    headers = ["ItemID", "Name", "Retail Site", "Categories", "Option Types", "View Count", "Trx Count", "# of adopters", "Import Price", "best_variant_id price", "Lowest Adopted Price", "Highest Adopted Price", "Median Adopted Price", "Lowest Trx Price", "Highest Trx Price", "Median Trx Price", "Seller w/ Lowest Trx Price", "Seller w/ Highest Trx Price"]

    require 'csv'
    fn = File.join(Rails.root, 'public/imported-items-sold.csv')
    File.delete(fn) if File.exists?(fn)
    io = File.open(fn, 'w')
    io.write CSV::Row.new(headers.collect(&:to_sym), headers, true)

    Spree::Product.where('retail_site_id is not null').
    in_batches(of: 100).each do|subq|
      subq.includes(:retail_site, :taxons, :option_types, :best_variant=>[:default_price] ).each do|p|
        var_ids = []
        import_price = p.master.price
        ad_prices = []
        seller_ids = Set.new
        p.variants_without_order.adopted.includes(:default_price).
        #order('spree_variants.id asc').
        #where(converted_to_variant_adoption: false).includes(:prices).
        all.each do|v|
          #if v.convert_into_variant_adoption!
          #  v.update_columns(converted_to_variant_adoption: true)
          #end
          #v.reset_preferred_variant_adoption!
          var_ids << v.id
          seller_ids << v.user_id
          ad_prices << v.price
        end

        row_values = [p.id, p.name, p.retail_site&.name, p.taxons.collect{|t| t.breadcrumb }.join(" | ") ]
        row_values += [p.option_types.collect(&:name), p.view_count, p.transaction_count]
        Spree::VariantAdoption.where(variant_id: var_ids).
        not_by_unreal_users.includes(:default_price, :user).each do|va|
          seller_ids << va.user_id
          ad_prices << va.price
        end
        ad_prices.sort!.uniq!

        trx_prices = []
        seller_lowest_trx_price = nil
        seller_highest_trx_price = nil
        Spree::Order.complete.not_by_unreal_users.with_product_id(p.id).includes(:seller, :line_items).each do|o|
          the_line_item = o.line_items.find{|li| li.product_id == p.id}
          next if the_line_item.nil? || o.seller.nil? || o.seller.phantom_seller? || o.seller.email =~ /\Aadmin@(example|shoppn)\.com/
          seller_lowest_trx_price = o.seller if seller_lowest_trx_price.nil? || the_line_item.price < trx_prices.min
          seller_highest_trx_price = o.seller if seller_highest_trx_price.nil? || the_line_item.price > trx_prices.max
          trx_prices << the_line_item.price
        end
        trx_prices.sort!.uniq!

        row_values += [seller_ids.size, import_price.to_f, p.best_variant&.price, ad_prices.first.to_f]
        row_values += [ad_prices.last.to_f, ad_prices[ad_prices.size / 2].to_f]
        row_values += [trx_prices.first.to_f, trx_prices.last.to_f, trx_prices[trx_prices.size / 2].to_f ]
        row_values += [seller_lowest_trx_price&.to_s, seller_highest_trx_price&.to_s]
        io.write CSV::Row.new(headers.collect(&:to_sym), row_values)
      end
    end.class
    io.close
  end


end
