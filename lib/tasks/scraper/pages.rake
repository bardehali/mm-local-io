require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

namespace :scraper do
  task :import_pages_from_csv => :environment do
    ARGV.shift
    csv_file = ARGV.shift
    puts "CSV file: #{csv_file}"
    puts '=' * 60

    DRY_RUN = ENV['DRY_RUN']
    max_rows = (ENV['MAX_ROWS'] || ENV['LIMIT'] ).to_i
    offset = ENV['OFFSET'].to_i

    CSV.parse(File.read(csv_file), headers: true).each_with_index do |csv_row, row_index|
      next if (offset > 0 && row_index + 1 < offset)
      puts ' .. %d' % [row_index] if row_index % 100 == 0
      if max_rows > 0 && row_index + 1 >= offset + max_rows
        break
      end

      begin
        row = csv_row.to_hash
        url_col_name, url_value = row.find_all{|k, v| k =~ /url|href|https?/i }.last
        page = DRY_RUN ? nil : ::Scraper::Page.add_if_needed(url_value)
        puts '%12s | %d | %s' % [::Scraper::Page.which_site(url_value).to_s, page.try(:id).to_i, url_value]

      rescue Exception => e
        puts "** #{e.message}\n" + e.backtrace.join("\n")
      end
    end
  end

  ##
  # Iterates over given path for page files and save them as Scraper::Page records, whose page source will be saved
  # on server locally.
  # Since these pages aren't actual URLs, better to specific site, so pages created can relate to some retail_site_id.
  #   rake scraper:import_pages_from_files "/drive/path_that_has_pages"
  # or rake scraper:import_pages_from_files[ioffer] "/drive/path_that_has_pages" - to specify the site
  task :import_pages_from_files, [:site_name] => [:environment] do|t, args|
    site_name = args['site_name']
    ARGV.shift
    folder = ARGV.shift

    site = site_name.present? ? Retail::Site.find_by_name(site_name) : nil
    default_store = site.retail_stores.first
    default_store ||= Retail::Store.create(retail_site_id: site.id, name: site_name.titlieze)

    puts "Site: #{site_name} #{site.try(:id)}"
    puts "Folder: #{folder}"
    puts '=' * 60

    DRY_RUN = ENV['DRY_RUN']
    find_method = DRY_RUN ? :find_or_initialize_by : :find_or_create_by
    max_rows = (ENV['MAX_ROWS'] || ENV['LIMIT'] ).to_i
    # offset = ENV['OFFSET'].to_i

    Dir.glob(File.join(folder, '**')).each_with_index do|page_file, index|
      break if max_rows > 0 && index + 1 >= max_rows
      begin
        file_name = File.basename(page_file).gsub(' ', '_')
        page = Scraper::Page.send(find_method, retail_site_id: site.try(:id), retail_store_id: default_store.id, url_path: '/' + file_name ) do|_page|
          _page.page_type = 'detail'
          _page.url_path = '/' + file_name
          _page.page_url = site.abs_url(_page.url_path)
        end

        image_urls = []
        File.open( page_file, 'r' ) do|f|
          source = f.read
          prod_attr = site.scraper.find_product_attributes( ::Mechanize::Page.new( URI(page.page_url), nil, source, 200, site.scraper ) )
          prod_attr[:photos].to_a.each do|image_url|
            begin
              site.media_downloads.find_or_create_by(media_type:'Image', url: image_url)
              image_urls << image_url
            rescue ActiveRecord::StatementInvalid => db_e
              puts " ** problem setting #{image_url}: #{db_e}"
            end
          end
        end
        if !DRY_RUN && page.id && page.file_path.blank?
          FileUtils.mkdir_p( page.page_dir )
          file_path = page.make_file_path
          FileUtils.cp(page_file, file_path)
          page.file_path = file_path
          page.save
        end
        puts '%6d | %2d | %s' % [page.try(:id).to_i, image_urls.size, page.file_path.to_s]
        image_urls.each do|image_url|
          puts '  ' + image_url
        end
      rescue Exception => page_e
        puts "** Problem reading file #{file_path}: #{page_e}"
      end
    end
  end

  # Syntax:
  #   rake scraper:fetch_pages
  # or using optional inner arguments like 
  #   rake scraper:fetch_pages[ioffer] - 1st inner argument to specify the site
  #   rake scraper:fetch_pages[ioffer,SAVED] - 2nd argument being file_status
  task :fetch_pages, [:site_name,:file_status] => [:environment] do|t, args|
    site_name = args[:site_name]
    retail_site = site_name.present? ? ::Retail::Site.find_by_name(site_name) : nil
    file_status = args[:file_status]

    start_time = Time.now

    query = file_status.present? ? ::Scraper::Page.where(file_status: file_status) : ::Scraper::Page.wait_for_fetch
    query = query.where(retail_site_id: retail_site.id) if retail_site
    query = apply_more_to_query(query)

    puts "Start time: #{start_time}"
    puts "query: #{query.to_sql}"
    puts "#{query.count} total pages to fetch"
    puts '=' * 60
    index = 0
    while (query.count > 0 && Time.now - start_time < 8.hours) # count of hours
      query.each do|page|
        index += 1
        puts ' .. %d at %s %s' % [index, Time.now.to_s(:db), '-' * 40] if index % 50 == 0
        puts '  %s' % [page.url_path]
        begin
          if page.page_type=='detail' && Spree::ScraperPageImport.where(scraper_page_id: page.id).count > 0
            puts "  Page #{page.id} already has created products: #{Spree::ScraperPageImport.where(scraper_page_id: page.id).collect(&:spree_product_id)}"
            page.update(file_status: 'FETCHED')
          else
            page.fetch_ruby!
          end
          sleep(3 + rand(5) )
        rescue Interrupt # => interupt_e
          confirm_to_exit  
        rescue Exception => page_e
          puts "** Problem fetching page (#{page.id}): #{page_e}\n#{page_e.backtrace}"
        end
      end

      query = ::Scraper::Page.wait_for_fetch
      query = query.where(retail_site_id: retail_site.id) if retail_site
      query = apply_more_to_query(query)
      puts "still #{query.count} more pages to fetch"
      puts '=' * 60
    end
  end


  ##
  # Considered environment variables as settings: 
  # those in task_helper task_helper convert_env_variables.
  desc 'Request certain products to initiate cache like a bot'
  task :request_product_pages => [:environment] do
    trap_signal_and_exit
    host = ENV['HOST'].present? ? ENV['HOST'] : 'localhost'
    check_cache = ENV['CHECK_CACHE']
    dry_run = ENV['DRY_RUN']
    cached_count = 0

    start_time = Time.now
    query = Spree::Product.where(nil)
    puts '#' * 60
    puts "total from retail sites: #{query.count}"
    query = apply_more_to_query(query)
    puts "query: #{query.to_sql}"
    puts "host: #{host}"
    puts "dry_run: #{dry_run}"
    puts "check_cache: #{check_cache}"
    puts "start_time: #{start_time}"
    index = @offset.to_i
    record_count = 0
    mechanize = a = Mechanize.new { |a|
      a.user_agent = 'iOffer Watcher'
      a.read_timeout = 60
      a.ssl_version, a.verify_mode = 'TLSv1', OpenSSL::SSL::VERIFY_NONE
    }
    
    query.each do|p|
      begin
        puts "#{index}) #{p.slug}      at #{Time.now.to_s(:db) }"
        cache_key = "views/product.#{p.id}.cart_form"
        cache_content = check_cache ? Rails.cache.exist?(cache_key) : nil
        if cache_content
          puts "  FOUND cache #{cache_key}"
        end
        unless dry_run || cache_content
          begin
            page = a.get("https://#{host}/products/#{p.slug}?show_cart_form=y")
          rescue Mechanize::ResponseCodeError => mechanize_e
            puts "  ** Server error: #{mechanize_e}"
            if mechanize_e.response_code.to_s == '502'
              puts ' .. starting puma fresh ..................'
              fresh_start_puma
              sleep(30)
              puts "  again: #{index}) #{p.slug}      at #{Time.now.to_s(:db) }"
              page = a.get("https://#{host}/products/#{p.slug}?show_cart_form=y")
            end
          end
          a_memory = available_memory / 1024
          puts "    avail memory #{a_memory}"
          if (1..600).include?(a_memory)
            puts ' .. graceful restart puma ..................'
            graceful_restart_puma
            sleep(30)
            puts "  again: #{index}) #{p.slug}      at #{Time.now.to_s(:db)}"
            page = a.get("https://#{host}/products/#{p.slug}?show_cart_form=y")
          else
            sleep_when(index, 5..8, 5, 10..16)
          end
        end
      rescue Exception => page_e
        puts "  ** Page error: #{page_e}"
      end
      index += 1
      record_count += 1
    end
    puts '#' * 60
    total_mins = (Time.now - start_time) / 1.minute
    puts "Done at: #{Time.now}, took #{total_mins} mins for #{record_count} products, so avg #{record_count / total_mins.to_f} per min"
  end


  ##
  # This would create Spree::Product from detail pages.
  # There's check of photos difference; if so would recreate product_photos
  # Sytanx:
  #   rake scraper:parse_pages
  # or rake scraper:parse_pages[ioffer] - to specify the site
  task :parse_pages, [:site_name] => [:environment] do|t, args|
    site_name = args[:site_name]
    retail_site = site_name.present? ? ::Retail::Site.find_by_name(site_name) : nil

    DRY_RUN = ENV['DRY_RUN']=='true' # 
    SKIP_G = ENV['SKIP_G']=='true'
    DEBUG = ENV['DEBUG']
    MAX_COUNT_OF_FAKE_USERS = 1000
    COUNT_OF_PHOTOS_TO_USE = 1
    DEFAULT_IQS = 40

    user_list_name = ENV['USER_LIST_NAME']
    unless user_list_name.present?
      user_list_name = [site_name&.downcase, 'importers', Time.now.strftime('%Y-%m-%d')].compact.join(' ')
      existing_list_count = Spree::UserList.where("name LIKE '#{user_list_name}%'").count
      user_list_name += " #{existing_list_count + 1}" if existing_list_count > 0
    end

    query = ::Scraper::Page.includes(:spree_products).where("page_type='detail' AND file_path IS NOT NULL")
    query = query.where(retail_site_id: retail_site.id) if retail_site
    query = apply_more_to_query(query)
    global_total = query.count

    # count of users based on number of pages
    user_g = Ioffer::UserGenerator.new(user_list: user_list_name, dry_run: DRY_RUN)
    user_list = user_g.user_list
    count_of_users = (query.count * rand(6..8) / 10.0).round 
    count_of_users = [10, Ioffer::EmailSubscription.count].min if count_of_users < 10
    unless DRY_RUN || SKIP_G
      user_g.batch_run_based_on(count_of_users, Ioffer::EmailSubscription, :email) do|u|
        user_list.user_list_users.find_or_create_by(user_id: u.id)
      end
      user_list.save
      puts ' -> resulting %d users' % [user_list.users.size]
    else
      puts 'Not generating users'
    end
    puts '-' * 60

    review_g = Ioffer::ProductReviewGenerator.new(dry_run: DRY_RUN, user_list_name: user_list_name.gsub('importers', 'reviewers'))
    review_user_list = review_g.user_list
    review_user_list.save unless DRY_RUN

    # In future, this might be set
    taxons = Spree::Taxon.where("name IN ('sneakers','shoes')").all
    taxon = taxons.find{|t| t.breadcrumb =~ /men.+(sneakers|shoes)/i } || taxons.first
    size_ot = taxon.option_types.find{|t| t.name =~ /\bsize?/i }
    puts ' -> size option type %s: %s' % [size_ot.name, size_ot.option_values.collect(&:presentation) ] if size_ot
    color_ot = taxon.option_types.find{|t| t.name =~ /\bcolors?/i }
    one_color_ov = color_ot ? color_ot.option_values.where("presentation LIKE 'One %'").first : nil

    puts "user_list_name: #{user_list.name}, review_user_list #{review_user_list.name}"
    puts "#{query.to_sql}"
    puts "#{query.count} pages to parse, out of global #{global_total}"
    puts "Dry run? #{DRY_RUN}"
    puts "now #{Time.now.to_s(:db)}"
    puts '=' * 60
    index = 0
    diff_count = 0
    pages_with_errors = Set.new
    query.each do|page|
      index += 1
      puts ' .. %d %s' % [index, '-' * 40] if index % 50 == 0
      begin
        a = page.product_attributes
        prod = page.spree_products.includes(:reviews).first
        if prod
          # prod = page.reparse!
          # ensure attributes correct
          page.spree_products.each do|p| 
            puts 'Existing: %6d | %6s | %6.2f vs %6.2f found | %2d reviews | %s' % [page.id, p.id.to_s, p.price.to_f, a[:price].to_f, p.reviews.size, p.name]
            p.attributes = { retail_site_id: p.retail_site_id || retail_site&.id, 
              iqs: DEFAULT_IQS, last_review_at: p.last_review_at || 1.day.ago, available_on: 6.hours.ago }
            unless DRY_RUN
              if a[:price] && a[:price] != p.price
                p.variants_including_master.includes(:default_currency_price).each{|v| v.default_currency_price.update_columns(price: a[:price]) }
                p.price = a[:price]
              end
              p.save
              review_g.batch_run_for( [p] ) if !SKIP_G && p.reviews.size < 3
            end
          end

        else
          adjusted_price = a[:price] || 90.0
          prod = Spree::Product.new(name: a[:name], description: a[:description], price: adjusted_price, 
            option_types: taxon.option_types, shipping_category: Spree::ShippingCategory.default )
          puts '-' * 30
          puts '%6d | %6s | %6.2f | %s' % [page.id, prod.id.to_s, prod.price.to_f, prod.name]
          
          RandomPicker.pick_indices( rand(8..10), user_list.users.size).each_with_index do|user_index, _index|
            user = user_list.users[user_index]
            puts '  %2d | %s' % [_index, user.to_s]
            if _index == 0
              prod.user_id = user.id
              prod.taxons = [taxon]
              prod.iqs = DEFAULT_IQS
              prod.available_on = 5.minutes.since
              prod.last_review_at = Time.now
              prod.retail_site_id = retail_site&.id
              unless DRY_RUN
                if prod.save
                  Spree::ScraperPageImport.find_or_create_by(spree_product_id: prod.id, scraper_page_id: page.id)
                  url = a[:photos]&.first
                  Spree::Image.create(viewable: prod.master, attachment: { io: open(url), filename: prod.name.to_underscore_id + url.split('.').last } ) if url.present?
                elsif DEBUG
                  binding.pry
                end
              end
            end

            common_variant_h = { product_id: prod.id, user_id: user.id, price: adjusted_price }
            variant = nil
            if size_ot
              size_ot.option_values.each do|ov|
                variant = Spree::Variant.new(common_variant_h)
                variant.option_values << ov
                variant.option_values << one_color_ov if one_color_ov
                # puts '    | %s' % [variant.sku_and_options_text]
                variant.save unless DRY_RUN
              end
            else
              variant = Spree::Variant.new(common_variant_h)
              variant.option_values << one_color_ov if one_color_ov
              # puts '    | %s' % [variant.sku_and_options_text]
              variant.save unless DRY_RUN
            end
          end
        end
        unless DRY_RUN
          if prod.save || prod.id
            page.update(file_status: 'SAVED')
            review_g.batch_run_for( [prod] ) unless SKIP_G
          end
        end
      rescue Interrupt # => interupt_e
        confirm_to_exit
      rescue Exception => e
        puts "** Error parsing #{page.id}: #{e}"
        puts "  file_path: #{page.file_path}, exists? #{File.exists?(page.file_path)}"
        puts e.backtrace.join("\n  ")
        pages_with_errors << page.id
        binding.pry if DEBUG
      end
    end
    puts '#' * 60
    puts "Done at #{Time.now.to_s(:db)}"
    puts "Different products count #{diff_count}"
    puts "pages_with_errors #{pages_with_errors}"
  end
end