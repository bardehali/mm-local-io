require 'csv'
require File.join(Rails.root, 'lib/tasks/task_helper')
require File.join(Rails.root, 'lib/tasks/server_helper')
include ::TaskHelper
include ::ServerHelper
include ::Spree::Service::ProductsTaskHelper

####################################
# Tasks

namespace :variants do
  ##
  # Iterates through Products and convert each Variant to VariantAdoption.
  # Can give environment variables:
  #    WHERE_CONDITION: extra where condition to Product query
  task :convert_to_adoptions => [:environment] do
    ARGV.shift
    where_cond = ARGV.shift
    total_q = Spree::Product.where(ENV['WHERE_CONDITION'] )
    puts "Query: #{total_q.to_sql}"
    puts "Total number of products to check: #{total_q.count}"
    batch_index = 0
    total_q.in_batches(of: 100, start: 0).each do|sub_q|
      puts '%d Batch - %s' % [batch_index, Time.now.to_s]
      sub_q.each do|p|
        p.variants.adopted.includes(:prices).where(converted_to_variant_adoption: false).all.each do|v|
          if v.convert_into_variant_adoption!
            v.update_columns(converted_to_variant_adoption: true) # deleted_at: Time.now
          end
          v.reset_preferred_variant_adoption!
        end
      end
      batch_index += 1
      sleep(60)
    end
  end

  task :clean_phantom_adoptions => [:environment] do
    delete_duplicates = false
    batch_index = 0
    pindex = 0
    latest_pid = nil
    print_beginning_info
    query = build_products_query_from_arguments

    query.in_batches(of: 50).each do|subq|
      puts "batch #{batch_index} at #{Time.now} --------------------------------------------"
      subq.each do|p| 
        begin
          p.variants_including_master_without_order.each do|v| 
            v.clean_phantom_adoptions!(true)
          end
        rescue ActiveRecord::Deadlocked => e
          puts "** Deadlocked problem for Product (#{p.id}: #{e.message}"
        end
        latest_pid = p.id
        pindex += 1
      end
      puts "  latest product #{latest_pid}"
      batch_index += 1
      sleep_when(pindex, nil, 10, 5)
    end
    print_ending_info
  end

  task :cleanup_variant_adoptions => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    print_beginning_info

    query = Spree::Variant.joins(:variant_adoption).distinct("#{Spree::Variant.table_name}.id")
    query = apply_more_to_query(query)
    puts "Query: #{query.to_sql}"
    puts "Total: #{query.count}"

    MAX = Spree::Product::PhantomGenerator::MAX_PHANTOM_VARIANT_RANGE.min
    batch_index = 0
    too_many_vcount = 0
    query.in_batches(of: 50) do|subq|
      puts "Batch #{batch_index} at #{Time.now} ------------------------"
      subq.includes(:product).each do|v|
        phantom_va_count = v.adoptions.by_phantom_sellers.no_line_item.count
        if @debug
          puts '%9d of %7d | %3d empty phantom VAs | %s' % [v.id, v.product_id, phantom_va_count, v.converted_to_variant_adoption.to_s]
        end
        if phantom_va_count > 0 && v.converted_to_variant_adoption
          unless @dry_run
            v.adoptions.by_phantom_sellers.no_line_item.all.each do|va|
              next if va.code == v.product.display_variant_adoption_code
              va.really_destroy!
            end
          end
        elsif phantom_va_count > MAX
          too_many_vcount += 1
          unless @dry_run
            v.adoptions.by_phantom_sellers.no_line_item.offset(MAX - 1).each do|va|
              next if va.code == v.product.display_variant_adoption_code
              va.really_destroy!
            end
          end
        end
      end
      sleep(30)
      batch_index += 1
    end

    print_ending_info
    puts "Total of variants w/ too many phantom adoptions: #{too_many_vcount}"
  end


  desc 'Find adopted variants inside product that have wrong combos of option types & values, non-leaf category'
  task :clean_option_problems => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    batch_index = 0
    puts "========================================= #{Time.now.to_s}"
    puts "dry run? #{@dry_run}, debug? #{@debug}"

    plist = Spree::ProductList.find_or_create_by(name:'Seller Products With Bad Options')
    # query = build_products_query_from_arguments
    query = Spree::Product.by_real_sellers
    query = apply_more_to_query(query)

    wrong_one_color = 0
    unnecessary_one_color = 0
    unnecessary_size_option_values = 0
    outside_of_option_types = 0
    not_enough_option_values = 0
=begin
    puts 'Clean unnecessary One Color or One Size variants'
    one_colors = Spree::OptionValue.where(presentation:"One Color").all
    s = ''
    Spree::Variant.joins(:option_value_variants).where("option_value_id IN (?)", one_colors.collect(&:id) ).where('spree_variants.created_at > ?', Time.local(2022,10,1)).includes(:product).all.find_all do|v|
      other_variants = v.product.variants.includes(:option_values => [:option_type]).all
      ot_id_of_one_value = v.option_values.find{|ov| ov.presentation =~ /one\s+color/i }&.option_type_id
      other_colors = other_variants.find_all{|other_v| other_v.option_values.find{|ov| ov.option_type_id == ot_id_of_one_value && !ov.one_value? } }
      b = other_colors.size > 0 && Spree::LineItem.where(variant_id: v.id).count == 0
      if b
        s << "%10d of %9d | %19s | %s\n" % [v.id, v.product_id, v.created_at.to_s(:db), v.sku_and_options_text]
        v.really_destroy! unlesss @dry_run
        unnecessary_one_color += 1
      end
      b
    end.size
=end
    
    one_color_single_color = Spree::OptionType.find_by(name:'One Color')&.option_values.first
    gcolor_one_color = Spree::OptionType.color.one_color_option_value
    query.in_batches(of: 50).each do|subq|
      puts '%d Batch - %s' % [batch_index, Time.now.to_s]
      subq.includes(:option_types, taxons:[:option_types], :user => [:role_users]).each do|p|
        problem_states = Set.new
        if p.option_types.find(&:size?) && p.taxons.none?{|t| t.option_types.any?(&:size?) }
          problem_states << 'size_for_non_size_category'
        end
        which_variants = ( ENV['ALL_VARIANTS'].to_s=='true' || p.user&.phantom_seller? ) ? :variants_without_order : :adopted_variants
        color_size_ids = p.option_types.find_all{|ot| ot.color? || ot.size? }.collect(&:id)
        if @debug
          puts '=' * 60; 
          puts "%d | %s | %s | phantom? %s" % [p.id, p.name, p.option_types.collect(&:name).join(', '), p.phantom?.to_s ];
        end
        user_and_option_value_ids = Set.new
        p.send(which_variants).includes(:user, :line_items, :option_values => [:option_type] ).each do|v|
          # if a) not active for some time, OR b) not in orders or cart
          #  soft delete their variants
          current_user_option_value_ids = [v.user_id] + v.option_values.collect(&:id).sort
          v.update_columns(converted_to_variant_adoption: false) if v.user_id == p.user_id && v.converted_to_variant_adoption
          wrong_one_color_ovv = v.option_value_variants.to_a.find{|ovv| ovv.option_value_id == one_color_single_color&.id }
          if wrong_one_color_ovv
            puts "  * Variant (#{v.id}) #{v.sku_and_options_text} wrong one color OV" if @debug
            wrong_one_color += 1
            wrong_one_color_ovv.update(option_value_id: gcolor_one_color.id) unless @dry_run
            problem_states << 'wrong_colors'
            v.option_values.reload
          else
            v_color_size_ids = v.option_values.collect(&:option_type).to_a.find_all{|ot| ot.color? || ot.size? }.collect(&:id)
            should_delete = false
            if v.user_id.nil? && p.user_id
              if @debug
                puts "  * Variant (#{v.id}) nil user_id given product's #{p.user_id}"
              end
              v.update_columns(user_id: p.user_id) unless @dry_run
            elsif user_and_option_value_ids.include?(current_user_option_value_ids)
              puts "  * Variant (#{v.id}) #{v.sku_and_options_text} is duplicate for user #{v.user_id}" if @debug
              should_delete = true
            elsif (v_color_size_ids - color_size_ids).size > 0
              puts "  * Variant (#{v.id}) #{v.sku_and_options_text} outside of option-types" if @debug
              outside_of_option_types += 1
              should_delete = true
              problem_states << 'wrong_colors'
            elsif v_color_size_ids.size < color_size_ids.size
              puts "  * Variant (#{v.id}) #{v.sku_and_options_text} not enough option-type-values" if @debug
              not_enough_option_values += 1
              should_delete = true
              problem_states << 'not_enough_options'
            end

            if should_delete
              puts "    DELETE Variant (#{v.id}) by #{v.user.to_s} last active at #{v.user&.last_active_at}, w/ #{v.line_items.to_a.size} line_items" if @debug
              if ( v.user.nil? || !v.user.active? || v.line_items.to_a.size == 0)
                v.destroy unless @dry_run
              end
            end
          end
          user_and_option_value_ids << current_user_option_value_ids
        end # each v
        p.auto_select_rep_variant! unless @dry_run
        # check non-leaf
        problem_states << 'non_leaf_category' if p.taxons.find{|t| t.children.count > 0 }
        if problem_states.size > 0
          plp = plist.product_list_products.find_or_initialize_by(product_id: p.id)
          plp.state = problem_states.to_a.sort.join(' ')
          plp.save
        end
      end # each p
      batch_index += 1
      sleep(10)
    end

    puts "========================================\nFinished at #{Time.now.to_s}"
    puts "Stats: wrong_one_color #{wrong_one_color}, outside_of_option_types #{outside_of_option_types}, unnecessary_one_color #{unnecessary_one_color}, not_enough_option_values #{not_enough_option_values}"
  end

  task :query_option_problems => [:environment] do
    outside_cnt = 0
    not_enough_cnt = 0
    Spree::Product.in_batches(of: 100).each do|subq|
      subq.includes(:option_types, :adopted_variants).each do|p|
        color_size_ids = p.option_types.find_all{|ot| ot.color? || ot.size? }.collect(&:id)
        p_outside_cnt = 0
        p_not_enough_cnt = 0
        p.variants.includes(:user, :option_values => [:option_type]).each do|v|
          v_color_size_ids = v.option_values.collect(&:option_type).to_a.find_all{|ot| ot.color? || ot.size? }.collect(&:id)
          user_cond = ( !v.user.active? || v.line_items.to_a.size == 0)
          if (outside_ot_ids = (v_color_size_ids - color_size_ids)).size > 0
            if user_cond
              p_outside_cnt += 1
            end
          elsif v_color_size_ids.size < color_size_ids.size
            if user_cond
              p_not_enough_cnt += 1
            end
          end
        end
        outside_cnt += 1 if p_outside_cnt > 0
        not_enough_cnt += 1 if p_not_enough_cnt > 0
      end
    end.class

    puts "Products w/ outside options #{outside_cnt}"
    puts "Products w/ not enough options #{not_enough_cnt}"
  end

  task :export_option_problems => [:environment] do
    headers = ['Product ID', 'Variant ID', 'Creator', 'Creator Phantom?', 'Produtc Option Types', 'Variant Combos/Option Values']
    fn = File.join(Rails.root, 'public/variants-with-insufficient-color-size.v2.csv')
    File.delete(fn) if File.exists?(fn)
    io = File.open(fn, 'w')
    io.write CSV::Row.new(headers.collect(&:to_sym), headers, true)

    batch_index = 0
    plist = Spree::ProductList.find_or_create_by(name:"items insufficient color + size" )
    plist.products.in_batches(of: 100).each do|subq|
      puts "batch #{batch_index} at #{Time.now} --------------------------------------------"
      subq.includes(:option_types, :user=>[:role_users] ).each do|p|
        otypes = p.option_types.collect(&:name).join(', ')
        p.variants_without_order.adopted.includes(:option_values => [:option_type] ).each do|v|
          not_enough_v = p.variants_without_order.all.find{|v| v.option_value_variants.size < 2 }
          next unless not_enough_v
          row_values = [p.id, v.id, p.user.to_s, p.user.phantom_seller?, otypes, v.sku_and_options_text]
          io.write CSV::Row.new(headers.collect(&:to_sym), row_values )
        end
      end
      batch_index += 1
    end.class
  ensure
    io.close
  end


  task :clean_maliciously_priced_adoptions => [:environment] do
    headers = ['Item ID', 'Title', 'Category', 'Recent TRX Count', 'Current Price', 'Recent Lowest Paypal Price', 'Recent Lowest Paypal Adopter', 'Lower Adoption Prices', 'Higher Adoption Prices', 'How many to cancel']

    trap_signal_and_exit
    convert_env_variables
    print_beginning_info

    populate_product_list_by_taxon

    # fn = File.join(Rails.root, ENV['FILENAME'] || 'public/sneakers-and-shoes-display-price-fixes.final.csv')
    # File.delete(fn) if File.exists?(fn)
    # io = File.open(fn, 'w')
    # io.write CSV::Row.new(headers.collect(&:to_sym), headers, true)

    paypal = Spree::PaymentMethod.paypal
    start_time = 4.months.ago.in_time_zone(-4).beginning_of_day
    DELETE_VARIANTS_LEVEL = false
    DEBUG_FIX_NEEDED = ( ENV['DEBUG_FIX_NEEDED'].to_s == 'true' )
    PRICE_RANGE = ENV['PRICE_RANGE'].present? ? eval(ENV['PRICE_RANGE']) : [9.0, 60.0] # 9.0, 30.0 for Shoes
    puts "Price range to compare: #{PRICE_RANGE}"
    VARIANT_MAX_PRICE = ENV['VARIANT_MAX_PRICE'].present? ? ENV['VARIANT_MAX_PRICE'].to_f : nil  # 90.0 for Shoes, none for Bags
    puts "VARIANT_MAX_PRICE? #{VARIANT_MAX_PRICE}"
    how_many_need_fix = 0
    pindex = 0
    
    query = build_products_query_from_arguments
    puts "Query: #{query.to_sql}"
    puts "Results: #{query.count} records"
    puts "dry_run? #{@dry_run}"


    query.includes(:taxons, best_variant:[:default_price]).each do|p|
      begin
        row_values = [p.id, p.name, p.taxons.first.breadcrumb]
        current_price = (p.best_price_record&.price || p.master.price).to_f
        row_values += [p.recent_completed_orders.count, current_price]
        lowest_paypal_price = nil
        lowest_paypal_adoption = nil
        all_prices = Set.new
        adoption_count = 0
        
        # Individual call of only adopted doesn't work
        p.reset_variant_price_to!(nil, VARIANT_MAX_PRICE) if VARIANT_MAX_PRICE
        p.clean_duplicate_variants!
        Spree::Variant.adopted.not_by_unreal_users.where(product_id: p.id).
          where("spree_variants.created_at > ?", start_time).order('id asc').
          includes(:default_price, user:[ store:[:store_payment_methods] ]).distinct.each do|v|
          next if v.nil? || v.user.nil? || v.price.nil?

          if DELETE_VARIANTS_LEVEL
            if v.user.store&.has_paypal? && (lowest_paypal_price.nil? || v.price < lowest_paypal_price)
              lowest_paypal_price = v.price
              lowest_paypal_adoption = v
            end
            all_prices << v.price
            if (PRICE_RANGE.first && v.price < PRICE_RANGE.first) || (PRICE_RANGE.last && v.price > PRICE_RANGE.last)
              adoption_count += 1
              # puts "* Deleting Variant #{v.id} $#{v.price}"
              v.destroy unless @dry_run
            end
          end
        end
        Spree::VariantAdoption.not_by_unreal_users.where(variant_id: Spree::Variant.where(product_id: p.id).select('id, deleted_at').collect(&:id) ).
          where("spree_variant_adoptions.created_at > ?", start_time).
          includes(:default_price, user:[ store:[:store_payment_methods] ]).each do|va|
            
          next if va.nil? || va.user.nil? 
          if va.price.nil?
            va.really_destroy!
            next
          end
          if va.user.store&.has_paypal? && (lowest_paypal_price.nil? || va.price < lowest_paypal_price)
            lowest_paypal_price = va.price
            lowest_paypal_adoption = va
          end
          all_prices << va.price
          if (PRICE_RANGE.first && va.price < PRICE_RANGE.first) || (PRICE_RANGE.last && va.price > PRICE_RANGE.last)
            adoption_count += 1
            puts '  VariantAdoption %13d | by %9d | $%7.2f | %19s' % [va.id, va.user_id, va&.price, va.created_at.to_s] if @debug || DEBUG_FIX_NEEDED
            va.update_columns(deleted_at: Time.now) unless @dry_run
          end
        end
        puts "Product #{p.id} current_price #{current_price} => Adoptions deleted #{adoption_count}" if @debug || (DEBUG_FIX_NEEDED && adoption_count > 0)
        how_many_need_fix += 1 if adoption_count > 0

        unless @dry_run
          p.auto_select_rep_variant!
          p.reload
          new_price = (p.best_price_record&.price || p.master.price).to_f
          puts " \\_ Product #{p.id} now set from #{current_price} to #{new_price}" if (@debug || DEBUG_FIX_NEEDED) && current_price != new_price
        end

        #row_values += [lowest_paypal_price, lowest_paypal_adoption&.user&.to_s, all_prices.to_a.find_all{|price| price < PRICE_RANGE.first }.sort ]
        #row_values += [all_prices.to_a.find_all{|price| price > PRICE_RANGE.last }.sort, adoption_count ]
        # io.write CSV::Row.new(headers, row_values)
      rescue Exception => p_e
        puts "** Error for Product #{p.id}: #{p_e.message}\n#{p_e.backtrace.join("\n  ")}"
      end
      pindex += 1
      puts "Index #{pindex} at #{Time.now} ----------------------------" if pindex % 100 == 0
      sleep_when(pindex, nil, 5, 2)
    end.class
    # io.close

    print_ending_info
    puts "How many products need fix: #{how_many_need_fix}"
  end

  task :generate_adoptions => [:environment] do
    pids = [584] # Spree::Product.all.select('id').collect(&:id).shuffle
    how_many_pids = pids.size # / (2 + rand(5))
    binding.pry # TODO: REMOVE
    0.upto( how_many_pids - 1) do|i|
      p = Spree::Product.find(pids[i] )
      next if p.nil?
      vars = p.variants
      vars = [p.master] if vars.blank?
      existing_seller_ids =  ( vars.collect(&:user_id) + [p.master.user_id] ).uniq
      sellers = []
      0.upto(1 + rand(3)) do
        other_sellers_q = Spree::User.real_sellers.where("#{Spree::User.table_name}.id NOT IN (?)", existing_seller_ids)
        sellers << other_sellers_q.offset( rand(other_sellers_q.count - 1) ).first
        existing_seller_ids << sellers.last.id
      end
      price_diff = rand(40)
      sellers.each do|u|
        vars.each do|v|
          va = v.variant_adoptions.find_or_initialize_by(user_id: u.id)
          va.price = (v.price || p.price) + ( 0.01 * (price_diff - 21) )
          va.save
        end
      end
    end # pids

    puts "| Product that have variant adoptions created: %d" % [
      Spree::VariantAdoption.where("created_at > ?", 5.minutes.ago).includes(:variant).collect{|va| va.variant.product_id }.uniq.size ]
    puts "| Users used to create variant adoptions: %d" % [
    Spree::VariantAdoption.where("created_at > ?", 5.minutes.ago).includes(:variant).collect{|va| va.user_id }.uniq.size ]
  end

  private

  def populate_product_list_by_taxon
    if (taxon_name = ENV['TAXON_NAME'] ).present?
      taxon = Spree::Taxon.find_by(name: taxon_name)
      if taxon
        puts "Found taxon (#{taxon.id}) #{taxon.breadcrumb}"
        plist = Spree::ProductList.find_or_create_by name: taxon.name
        ENV['PRODUCT_LIST_ID'] = plist.id.to_s
        plist.product_list_products.delete_all

        taxon.populate_products_into!(plist)

        puts " -> final count of products in category: #{plist.product_list_products.count}"
      end
    end
  end

end
