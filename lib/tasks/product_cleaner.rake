require 'csv'
require 'open-uri'
require File.join(Rails.root, 'lib/tasks/task_helper')
require File.join(Rails.root, 'lib/spree/service/products_task_helper')
include ::TaskHelper
include ::Spree::Service::ProductsTaskHelper

####################################
# Tasks

namespace :products do
  ##
  # Fields can be:
  #   User or user_id or seller,Email,Location,Member Since,Phone,Registration,Name,GMS,TRX,Positive,Negative,Rating Score
  # Options set by environment variables (those can be set in convert_env_variables)
  #   EXTRA_WHERE - the extra SQL condition to query
  task :convert_into_phantom => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    ARGV.shift
    puts "========================================= #{Time.now.to_s}"
    puts "dry run? #{@dry_run}"
    puts "max_rows #{@max_rows}"

    query = Spree::Product.from_retail_sites.where("(user_id is null or user_id IN (?))", [Spree::User.fetch_admin.id] )
    query = apply_more_to_query(query)

    puts query.to_sql
    puts 'Total %d scraped products' % [query.count]

    # those that are accepted to have their closest option types based on these taxons
    accepted_taxon_ids = [48, 34, 41, 3838, 70, 77, 576, 84, 91, 112, 422, 423, 424, 425, 591, 436, 437, 438, 439, 591, 592, 428]
    accepted_breadcrumbs = Spree::Taxon.where(id: accepted_taxon_ids).collect(&:breadcrumb)
    other_option_types = [Spree::OptionType.one_color, Spree::OptionType.one_size]

    batch_index = -1
    row_count = 0
    ActiveRecord::Base.logger.level = :warn
    query.in_batches(of: 50, start: 1) do|subq|
      batch_index += 1
      puts "Batch #{batch_index} at #{Time.now} -----------------------"
      subq.includes(:taxons, :option_types => [:option_values]).each do|p|
        row_count += 1
        existing_option_type_ids = p.option_types.collect(&:id)
        existing_breadcrumb = p.taxons.first&.breadcrumb || ''
        is_accepted_taxon = accepted_breadcrumbs.find{|b| existing_breadcrumb.starts_with?(b) }
        unless is_accepted_taxon
          run_unless_dry_run do
            p.option_types = other_option_types
          end
        end
        if @debug
          puts '%6d | %8d | %60s | %s' % [row_count, p.id, p.name, 
            is_accepted_taxon ? p.option_types.collect(&:name) : other_option_types.collect(&:name) ]
        end
        run_unless_dry_run do
          p.convert_into_phantom_product!
        end
        break if @max_rows && row_count >= @max_rows.to_i
      end
      break if @max_rows && row_count >= @max_rows.to_i
    end
    
    puts "========================================\nFinished at #{Time.now.to_s}"
  end


  desc 'Find duplicate same-option-values-combo legacy variants and combine into one'
  task :combine_variant_adoptions => [:environment] do
    trap_signal_and_exit
    convert_env_variables

    print_beginning_info

    output_file = find_or_default_output(false)
    headers = ["ItemID", "Name", "Retail Site", "Categories", "Option Types", "Days Since Listing", 
      "View Count", "Trx Count", "Total Variants", "From Creator", "From Adopters", "# of Unique Combos"]
    if output_file
      output_file.write CSV::Row.new(headers.collect(&:to_sym), headers, true)
    end

    query = build_products_query_from_arguments
    puts query.to_sql
    puts 'Total %d products' % [query.count]

    batch_count = 0
    query.in_batches(of: 100, start: 1) do|subq| 
      puts "Batch #{batch_count}"
      subq.includes(user:[:role_users], variants:[:default_price, option_values:[:option_type] ] ).each do|p| 
        map = p.options_map(nil, exclude_zero_value: false, include_phantom_variants: true ).option_value_ids_to_variants_map

        puts '%8d | %60s | %d combos' % [p.id, p.name, map.size] if @debug
        if output_file
          row_values = [p.id, p.name, p.retail_site&.name, p.taxons.collect{|t| t.breadcrumb }.join(" | ") ]
          row_values += [p.option_types.collect(&:name), ((Time.now - p.created_at) / 1.day).round ]
          row_values += [p.view_count, p.transaction_count]
          row_values += [p.variants.count, p.original_variants.count, p.adopted.count]
          row_values += [map.size]
          output_file.write CSV::Row.new(headers.collect(&:to_sym), row_values)
        end
        map.each_pair do|combo_ov_ids, vars|
          next if vars.size < 2
          base_var = vars.find{|v| v.user_id == p.user_id } || vars.first
          vars.each do|v|
            next if v.id == base_var.id
            puts "        Var (%8d) w/ #{combo_ov_ids} combining %d adoptions into base %8d %s w/ %s" % [v.id, v.variant_adoptions.count, base_var.id, base_var.sku_and_options_text, base_var.option_values.collect(&:id).sort.collect(&:to_s).join(', ') ]
            unless @dry_run
              v.variant_adoptions.update_all(variant_id: base_var.id)
              v.update_columns(deleted_at: Time.now)
            end
          end
          Spree::VariantAdoption.where(variant_id: base_var.id).includes(:default_price).all.order('id desc').group_by(&:user_id).each_pair do|user_id, adoptions|
            next if adoptions.size < 2
            adoptions.sort_by!(&:price)
            puts "        Cleaning user %8d those %d adoptions, keeping $#{adoptions.first&.price}" % [user_id, adoptions.size]
            unless @dry_run
              Spree::VariantAdoption.where(id: adoptions[1, adoptions.size].collect(&:id) ).delete_all
            end
          end
        end
        unless @dry_run
          # p.schedule_to_update_variants!
          p.auto_select_rep_variant!
        end
      end
      batch_count += 1
    end
    
    print_ending_info
  end

  
  desc 'For each generate phantom sellers, and either variants of variant_adoptions'
  task :generate_phantom_variants => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    ARGV.shift
    puts "========================================= #{Time.now.to_s}"
    puts "dry run? #{@dry_run}, debug? #{@debug}"
    puts "max_rows #{@max_rows}"

    query = build_products_query_from_arguments

    inactive_plist = Spree::ProductList.find_or_create_by(name: 'inactive_seller_items')
    inactive_timestamp = 1.year.ago

    batch_index = 0
    query.in_batches(of: 50).each do|subq|
      puts '%d Batch - %s' % [batch_index, Time.now.to_s]
      subq.includes(:user => [:role_users] ).each do|p|
        begin
          # same code inside p.more_after_save_updates!
          if @debug
            puts '%8d | %60s | phantom? %s' % [p.id, p.name, p.phantom?.to_s]
          end
          p.skip_after_more_updates = true
          vars = p.phantom? ? p.generate_phantom_variants! : p.variants_including_master
          p.generate_phantom_variant_adoptions!
          if p.phantom? # clean duplicate VA
            p.generate_phantom_variant_adoptions! if p.phantom?
            p.variants_including_master_without_order.includes(:variant_adoptions).each{|v| existing = Set.new; v.variant_adoptions.each{|va| va.destroy if existing.include?(va.user_id); existing << va.user_id; } }.class
          else
            inactive_plist.product_list_products.find_or_create_by(product_id: p.id) if p.user&.last_active_at.nil? || p.user&.last_active_at < inactive_timestamp
          end
          if vars.last
            p.update_columns(rep_variant_id: vars.last.id || vars.master&.id )
          end
          puts '  %d variants' % [vars.size]
        rescue ActiveRecord::Deadlocked => deadlock_e
          puts "** Deadlocked Error for Product(#{p.id}): #{deadlock_e.message}\n.. rest for 3 mins"
          sleep(180)
        rescue Exception => e
          puts "** Error for Product(#{p.id}): #{e.message}"
        end 
      end
      batch_index += 1
      sleep(60)
    end
    
    puts "========================================\nFinished at #{Time.now.to_s}"
  end

  desc 'For each generate product reviews'
  task :generate_phantom_reviews => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    ARGV.shift

    print_beginning_info

    query = build_products_query_from_arguments

    batch_index = 0
    query.in_batches(of: 20).each do|subq|
      puts '%d Batch - %s' % [batch_index, Time.now.to_s]
      subq.each do|p|
        begin
          original_count = p.reviews.count
          reviews = p.generate_product_reviews!(@dry_run)
          if @debug
            puts '%8d | %60s | %3d | %d + %d reviews' % [p.id, p.name, p.iqs, original_count, reviews.size]
          end
          if (review = (reviews.first || p.reviews.last) )
            review.skip_check_permission = false
            review.recalculate_product_rating
          end
        rescue Exception => e
          puts "** Error for Product(#{p.id}): #{e.message}"
        end
      end
      batch_index += 1
      sleep(10)
    end

    print_ending_info
  end

end
