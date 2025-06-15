require 'active_storage/service/disk_service'
require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

namespace :images do

  desc 'Iterates over images and download file into local storage'
  task :ensure_files => :environment do
    trap_signal_and_exit
    service = ActiveStorage::Blob.service
    iterate_over_images do|img|
      begin
        local = service.path_for(img.attachment.key)
        puts '%5s | %s' % [service.exist?(local).to_s, local]
        img.ensure_attachment_file_saved!
      rescue Exception => image_e
        puts "** Problem w/ #{img.id}: #{image_e}\n"
      end
    end
  end

  desc 'For a set of products and ensure images are processed and uploaded. Needed when async image processing after calls are breaking'
  task :ensure_images_processed => :environment do
    trap_signal_and_exit
    convert_env_variables

    print_beginning_info

    query = build_products_query_from_arguments
    puts query.to_sql
    puts 'Total %d products' % [query.count]

    batch_count = 0
    last_p_info = {}
    query.in_batches(of: 100, start: 1) do|subq| 
      puts "Batch #{batch_count} at #{Time.now} last product #{last_p_info} -----------------------------------"
      subq.includes(:variants_including_master => [:images]).each do|p|
        if @debug
          puts '%9d | %60s | %3d variants' % [p.id, p.name[0,60], p.variants_including_master.count ]
        end
        last_p = { id: p.id, created_at: p.created_at }
        unless @dry_run
          p.ensure_images_processed!
        end
      end
      batch_count += 1
    end

    print_ending_info
  end

  ##
  # Usable environment variables: MAX_ROWS, LIMIT, OFFSET, WHERE_CONDITIONS, SORT
  desc 'Iterates over images and call to process attachment variants'
  task :ensure_attachment_variants => :environment do
    trap_signal_and_exit
    service = ActiveStorage::Blob.service
    where_conditions = "viewable_type='Spree::Variant'"
    where_conditions << " AND #{ENV['WHERE_CONDITIONS'] }" if ENV['WHERE_CONDITIONS'].present?
    iterate_over_images(where_conditions) do|img, index|
      begin
        local = service.path_for(img.attachment.key)
        puts '%7d) %7d | %5s | %s' % [index, img.id, service.exist?(local).to_s, local]
        img.ensure_attachment_variants_processed!
        sleep_when(index, nil, 10, 5)
      rescue Interrupt
        confirm_to_exit
      rescue Exception => image_e
        puts "** Problem w/ #{img.id}: #{image_e}\n"
      end
    end
  end

  desc 'Iterates over product images and upload local file to remote ActiveStorage service'
  task :sync_storage_from_local => :environment do
    dry_run = ENV['DRY_RUN'].present?
    delete_blank_images = ENV['DELETE_BLANK_IMAGES'].to_s == 'true'
    puts "Dry Run? #{dry_run}, delete blank images? #{delete_blank_images}"

    storage_config = YAML.load( File.read(Rails.root.join('config/storage.yml')) )
    INLINE_RUBY_REGEXP = /<%=(.+)\-?%>/
    local_root = storage_config['local']['root']
    if (m = local_root.match(INLINE_RUBY_REGEXP) )
      local_root.gsub!(m[0], eval(m[1]).to_s )
    end
    puts "Disk root: #{local_root}"

    disk_service = ActiveStorage::Service::DiskService.new( root: local_root )
    current_service = ActiveStorage::Blob.service

    iterate_over_products(ENV['MAX_PRODUCTS'] || ENV['MAX_ROWS'] || ENV['LIMIT']) do|product|
      images_count = product.variant_images.size
      product.variant_images.each do|img|
        begin
          local = disk_service.path_for(img.attachment.key)
          current_exist = current_service.exist?(img.attachment.key)
          puts '%5s | %8d | %6d | %s' % [ current_exist, current_exist ? img.attachment.download.size.to_s : '0', img.viewable.product_id, local];

          unless current_exist && img.attachment.download.present?
            if File.exist?(local)
              img.attachment.attach(io: File.open(local), filename: img.attachment.filename.to_s ) unless dry_run
              # current_service.upload(img.attachment.key, File.open(local) )
            elsif img.old_filepath.present? && File.exists?(img.old_filepath)
              img.attachment.attach(io: File.open(img.old_filepath), filename: img.attachment.filename.to_s ) unless dry_run
            end
          end
          if img.reload.attachment.download.blank?
            puts '** %7d of product %8d still blank: ' % [img.id, img.viewable.product_id]
            images_count -= 1
            img.destroy if !dry_run && delete_blank_images
          end
        rescue Interrupt # => interupt_e
          confirm_to_exit
        rescue Exception => image_e
          puts "** Problem w/ #{img.id}: #{image_e}\n"
        end
        puts "** Product #{product.id} would have no images" if images_count == 0
      end # each product
    end
  end
end

# @total_products max count of products to query
def iterate_over_products(total_products = nil, &block)
  start_time = Time.now
  total_products = Spree::Product.count

  query = Spree::Product.order('id desc')
  query = apply_more_to_query(query)
  this_query_count = query.count

  puts "#{this_query_count} of #{total_products} total products, started #{start_time}"
  puts "SQL: #{query.to_sql}"
  i = 0

  query.each do|product|
    i += 1
    puts "#{i * 100} -------------------------" if i % 100 == 0
    yield product
  end
  end_time = Time.now
  puts "took #{ (end_time - start_time) / 60} minutes"
end

def iterate_over_images(where_conditions = nil, &block)
  convert_env_variables

  query = Spree::Image.where(where_conditions)
  query = query.order(ENV['SORT']) if ENV['SORT'].present?

  total = @max_rows || query.count
  limit = @limit && @limit > 1 ? @limit : 100
  offset = @offset || 0
  start_time = Time.now
  global_index = 0
  puts "Total of #{total} images w/ #{where_conditions}, started #{start_time}"
  0.upto( (total.to_f / limit).ceil ).each do|i| 
    puts "#{i * limit} -------------------------"; 
    query.offset(offset + i * limit).each do|img| 
      next if img.attachment.nil?
      yield img, global_index
      global_index += 1
    end
  end
  end_time = Time.now
  puts "took #{ (end_time - start_time) / 60} minutes"
end