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

  task :log_product_keywords => [:environment] do
    query = build_products_query_from_arguments
    batch_count = 0
    query.in_batches do|subq|
      puts "Batch #{batch_count} #{Time.now} -----------------------------------"
      subq.select('name').each do|p|
        ::ProductKeyword.log_product(p)
      end
      batch_count += 1
    end
  end

  desc 'Use of product.auto_select_rep_variant!'
  task :update_rep_variant => [:environment] do
    trap_signal_and_exit
    convert_env_variables

    print_beginning_info

    query = build_products_query_from_arguments
    puts query.to_sql
    puts 'Total %d products' % [query.count]

    batch_count = 0
    query.in_batches(of: 100, start: 1) do|relation| 
      puts "Batch #{batch_count} #{Time.now} -----------------------------------"
      relation.includes(user:[:role_users] ).each do|p| 
        if @debug
          best_price_r = p.best_price_record
          selected_va = p.display_variant_adoption || p.master.select_rep_variant_adoption

          puts '%8d | %60s | BestPrice %16s (%10s) | /vp/%s' % 
            [p.id, p.name[0,60], best_price_r.class.to_s.split('::').last, best_price_r&.id.to_s, selected_va&.id.to_s] if @debug
        end

        unless @dry_run
          p.auto_select_rep_variant!
        end
      end
      batch_count += 1
    end
    
    print_ending_info
  end

  desc 'Reset phantom adoptions prices w/ category prices and generate phantom variants'
  task :reset_phantom_adoptions => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    csv_file = ENV['CSV_FILE']
    csv = nil
    csv_headers = nil
    if csv_file.present?
      csv_file = File.join(Rails.root, csv_file) if not csv_file.start_with?('/')
      puts "CSV file: #{csv_file}"
      csv_headers = ['Item ID', 'Title', 'Retail Site', 'Category', 'Category ID', 'Brands', 'View Count', 'TRX Count', 'Last TRX', 'Last Adoption', 'Previous Best Price', 'Adoption Prices', 'Adoption Price Out of Range?', 'Category Re-price']
      csv = File.open(csv_file, 'w')
      csv.write CSV::Row.new(csv_headers, csv_headers, true)
    end

    print_beginning_info

    query = if @extra_where.present? || ENV['PRODUCT_LIST_NAME'].present? || ENV['PRODUCT_LIST_ID'].present?
        build_products_query_from_arguments
      else 
        Spree::Product.joins(:line_items => :order).where("state='complete' and completed_at > ?", Time.local(2022,5,1, 5,0,0 )).distinct
    end
    puts query.to_sql
    puts 'Total %d products' % [query.count]

    Spree::TaxonPrice.update_all(last_used_product_id: 0)

    batch_count = 0
    flopped_product_ids = Set.new
    query.in_batches(of: 100, start: 1) do|relation| 
      puts "Batch #{batch_count} #{Time.now} -----------------------------------"
      relation.includes(:retail_site, :option_types, :taxons,
        variants_including_master_without_order:[:option_value_variants] ).each do|p| 
        if @debug
          phantom_ad_count = p.variants_including_master_without_order.all.collect{|v| v.variant_adoptions.by_phantom_sellers.count }.sum
          if phantom_ad_count == 0
            puts '%8d | %60s | %3d vars | %2d phantom ads' % [p.id, p.name[0,60], p.variants.count, phantom_ad_count]
          end
        end

        p.generate_phantom_variant_adoptions! unless @dry_run

        taxon_price = p.taxons.first&.next_taxon_price
        if @debug
          puts "%9d | %60s | price %6s | (%5s) %s" % 
            [p.id, p.name, taxon_price&.price ? ('%.2f' % taxon_price&.price) : '', taxon_price&.taxon_id.to_s, p.taxons.first&.breadcrumb.to_s ]
        end

        if taxon_price
          cur_prices = Set.new
          has_out_of_range = false
          p.variants_including_master_without_order.includes(user:[:role_users] ).each do|v|
            cur_prices << v.default_price.price if v.default_price
            v.default_price.update_columns(price: taxon_price.price) if !@dry_run && (v.user&.admin? || v.user&.test_or_fake_user?)
            v.variant_adoptions.by_phantom_sellers.includes(:default_price, :user).each do|va|
              cur_prices << va.default_price.price if va.default_price
              is_cur_price_out_of_range = !p.taxons.first.is_price_within_range?(va.default_price&.price, va.default_price&.currency)
              has_out_of_range = true if is_cur_price_out_of_range
              if @debug && @dry_run && is_cur_price_out_of_range
                puts "        Old %10d  %.2f by %s on %s" % [va.id, va.price, va.user&.login.to_s, va.default_price.updated_at.to_s(:db)]
                flopped_product_ids << p.id
              end
              unless @dry_run
                if va.default_price.nil?
                  Spree::AdoptionPrice.create(variant_adoption_id: va.id, price: taxon_price.price, currency:'USD')
                else
                  va.default_price.update_columns(price: taxon_price.price, previous_amount: va.default_price.price )
                end
              end
            end
          end

          if csv && has_out_of_range
            csv.write CSV::Row.new(csv_headers, [p.id, p.name, p.retail_site&.name, p.taxons.first&.breadcrumb, 
                p.taxons.first&.id, p.brands.collect(&:presentation).join(', '), p.view_count, 
                p.calculate_transaction_count, p.last_completed_order&.completed_at&.to_mid_s, 
                p.all_adoptions.sort_by(&:created_at).last&.created_at&.to_mid_s,
                p.best_price_record&.price, cur_prices.to_a.collect(&:to_s).join(', '), has_out_of_range,
                taxon_price.price
              ] )
          end

          # p.auto_select_rep_variant! unless @dry_run
          taxon_price.update(last_used_product_id: Time.now.to_i + p.id)
        end
      end
      batch_count += 1
    end
    csv.close if csv
    
    print_ending_info

    puts "Flopped price products: #{flopped_product_ids}"
  end

  desc 'Use of product.auto_select_rep_variant!'
  task :try_best_variants => [:environment] do
    trap_signal_and_exit
    convert_env_variables

    print_beginning_info

    output_file = find_or_default_output(false)
    headers = ["ItemID", "Name", "Retail Site", "Categories", "Option Types", "Days Since Listing", 
      "View Count", "Trx Count", "Import/Master Price", 
      "Last TRX Price", "Last TRX Number", 
      "Target Variant ID", "Target Variant Price", "Target Preferred Variant Adoption Price", "Target Best Variant Price", "URL"]
    if output_file
      output_file.write CSV::Row.new(headers.collect(&:to_sym), headers, true)
    end

    query = build_products_query_from_arguments
    puts query.to_sql
    puts 'Total %d products' % [query.count]

    batch_count = 0
    query.in_batches(of: 100, start: 1) do|relation| 
      puts "Batch #{batch_count}"
      relation.includes(user:[:role_users] ).each do|p| 
        if @debug || output_file
          selected_v = p.select_best_variant( !p.retail_site_id.nil? ) || p.master

          puts '%8d | %60s | TRX %3d | (%s) %s w/ $%s' % [p.id, p.name, p.transaction_count, selected_v&.id.to_s, selected_v ? selected_v.sku_and_options_text : '', selected_v&.price.to_s] if @debug
          if output_file
            row_values = [p.id, p.name, p.retail_site&.name, p.taxons.collect{|t| t.breadcrumb }.join(" | ") ]
            row_values += [p.option_types.collect(&:name), ((Time.now - p.created_at) / 1.day).round ]
            row_values += [p.view_count, p.transaction_count, p.price]
            latest_order = Spree::Order.complete.not_by_unreal_users.with_product_id(p.id).includes(:line_items).order('completed_at desc').first

            row_values += [ latest_order ? latest_order.line_item_of_product(p.id)&.variant&.price : nil]
            row_values += [ latest_order&.number ]

            select_trx_only = p.select_best_variant(false)
            row_values += [ select_trx_only&.id, select_trx_only&.price, select_trx_only&.preferred_variant_adoption&.price]

            row_values += [ selected_v&.price&.to_f ]
            row_values += [url_for_product(p)]
            output_file.write CSV::Row.new(headers.collect(&:to_sym), row_values)
          end
          unless @dry_run
            p.update_columns(best_variant_id: selected_v&.id)
            p.reindex_document
          end
        end
      end
      batch_count += 1
    end
    
    print_ending_info
  end

  desc 'Update stats of Spree::Product table'
  task :update_product_stats => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    print_beginning_info
    puts '=' * 60
    puts "products:update_product_stats start at #{Time.now.to_s(:db)}"
    pids = Set.new
    Spree::LineItem.joins(:order).where("completed_at is not null and state='complete'").
      select('product_id').distinct('product_id').in_batches(of: 100, start: 1) do|line_item_q| 
      
        Spree::Product.where(id: line_item_q.collect(&:product_id).uniq ).in_batches(of: 50, start: 1) do|subq| 
        subq.includes(user:[:role_users] ).each do|p| 
          next if pids.include?(p.id)
          pids << p.id
          txn_count = Spree::Order.complete.not_by_unreal_users.joins(:line_items).where("#{Spree::LineItem.table_name}.product_id=#{p.id}").count;  
          p.update_columns(transaction_count: txn_count) unless @dry_run
          if @debug
            ordered_record = txn_count > 0 ? p.last_ordered_record : nil
            next if ordered_record.nil?
            row_values = [p.id, p.name[0,60], p.phantom? ? 'P' : ' ', txn_count, p.price.to_f, 
              ordered_record ? ordered_record.price.to_f : 0.0, p.best_price_record.price.to_f, p.select_best_variant&.id.to_s ]
            #puts "%6d | %60s | %1s | %4d txns | $%7.2f | last_trx $%7.2f | best_record $%7.2f | best_var %8s" % row_values
            puts CSV::Row.new(%w(product_id title phantom? trx_count master_price last_trx_price best_price_record_price best_variant_id).collect(&:to_sym), row_values).to_s
          end
          if txn_count > 0
            # p.auto_select_rep_variant! unless @dry_run
          end
          unless @dry_run
            if p.indexable? 
              p.es.update_document
            elsif p.es.exists_in_es?
              p.es.delete_document
            end
          end
        end
      end # line_item_q
    end
    puts "products:update_product_stats done at #{Time.now.to_s(:db)}"
    puts '=' * 60
    print_ending_info
  end

  desc 'Use of product.auto_select_rep_variant! to set best_variant_id'
  task :clean_many_colors => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    ARGV.shift
    puts "========================================= #{Time.now.to_s}"
    puts "dry run? #{@dry_run}, debug? #{@debug}"
    puts "max_rows #{@max_rows}"

    color_ot_ids = Spree::OptionType.colors.collect(&:id)
    query = Spree::Product.joins(:product_option_types).where("option_type_id IN (?)", color_ot_ids)
    query = apply_more_to_query(query)

    puts query.to_sql
    puts 'Total %d products' % [query.count]

    product_count = 0
    batch_i = 0
    query.in_batches(of: 50) do|subq|
      subq.includes(:taxons, :option_types, :variants_including_master ).each do|p|
        p_color_ot = p.option_types.find{|ot| ot.color? && ot.name.downcase != 'one color' }
        if @debug
          puts '=' * 60; 
          puts "%d | %s | %s" % [p.id, p.name, p.option_types.collect(&:name).join(' | ') ];
        end
        next if p_color_ot.nil?
        p.clean_many_colors!(@dry_run)
        product_count += 1
      end
      puts "Batch #{batch_i} at #{Time.now.to_s(:db)}, product_count #{product_count} ---------------------"
      sleep(30) if product_count % 50 == 49
      sleep(30) if batch_i % 20 == 19
      batch_i += 1
    end.class
    product_count
    
    puts "========================================\n#{product_count} products processed\nFinished at #{Time.now.to_s}"
  end


  task :generate_reviews => [:environment] do
    trap_signal_and_exit
    query = Spree::Product.from_retail_sites.where('reviews_count = 0')
    puts "Query: #{query.to_sql}"
    puts "Total: #{query.count}"

    batch_i = 0
    query.in_batches(of: 100) do|subq|
      puts "Batch #{batch_i} at #{Time.now.to_s(:db)}  ---------------------"
      subq.each do|p| 
        p.generate_product_reviews!
        p.recalculate_rating
      end
      batch_i += 1
    end

  end


end

