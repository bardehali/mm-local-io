require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

namespace :es do
  desc 'Rebuilds Spree::Product ES index from scratch'
  task :rebuild_products_index => [:environment] do
    start_time = Time.now
    puts "rebuild_products_index of #{Spree::Product.search_indexable.count} products, starting at #{Time.now.to_s(:db)} ----------------------------"
    Spree::Product.es.rebuild_index!
    end_time = Time.now
    puts "--------------------------------\n Took #{(end_time - start_time) / 1.minute} minutes"
  end

  ##
  # In batches, update each search_indexable product efficiently.
  # Environment variables as options
  #   SLEEP_BETWEEN_BATCHES [Integer] wait for some seconds before next batch for break on system resources. default none
  desc 'Reindex Spree::Product in ES index one by one'
  task :reindex_products => [:environment] do

    FORCE_REINDEX = ( ENV['FORCE_REINDEX'].to_s == 'true' )
    SLEEP_BETWEEN_BATCHES = ENV['SLEEP_BETWEEN_BATCHES'].to_i
    start_time = Time.now
    puts "reindex_products of #{Spree::Product.search_indexable.count} products, FORCE_REINDEX? #{FORCE_REINDEX} starting at #{Time.now.to_s(:db)} ----------------------------"
    batch_no = 1
    Spree::Product.search_indexable.in_batches(of: 50, start: 0) do|batch_q|
      batch_start_time = Time.now
      puts "  reindexing batch #{batch_no} at #{batch_start_time.to_s(:db)}"
      batch_q.includes_for_indexing.each do|p|
        if FORCE_REINDEX
          p.reindex_document
        else
          p.index_document
        end
      end
      batch_end_time = Time.now
      puts "    batch #{batch_no} took #{(batch_end_time - batch_start_time) / 1.second} seconds"
      sleep(SLEEP_BETWEEN_BATCHES) if SLEEP_BETWEEN_BATCHES > 0
      batch_no += 1
    end

    end_time = Time.now
    puts "--------------------------------\n Took #{(end_time - start_time) / 1.minute} minutes"
  end

  desc 'Rebuilds Spree::OptionValue ES index from scratch'
  task :rebuild_option_values_index => [:environment] do
    start_time = Time.now
    puts "rebuild_option_values_index of #{Spree::OptionValue.count} option values, starting at #{Time.now.to_s(:db)} ----------------------------"
    Spree::OptionValue.es.rebuild_index!
    end_time = Time.now
    puts "--------------------------------\n Took #{(end_time - start_time) / 1.minute} minutes"
  end

  ##
  # For each of these record types, Spree::OptionValue and Spree::Product,
  # iterates through each record (including those w/ deleted_at set), update one by one.
  # Environment variables checked for use:
  #   START_TIME [parsable format of time] starting part
  #   START_TIME_IN_RUBY [Ruby code that defines] the Ruby would be evaluated, for example, '3.days.ago'
  desc 'Synchronizes ES index by looking at created_at and deleted_at (if any) times'
  task :sync_indices => [:environment] do
    start_time = Time.now
    SYNCING_STATUS_FILE = File.join(Rails.root, 'log/es.syncing_status.txt')
    SLEEP_BETWEEN_BATCHES = ENV['SLEEP_BETWEEN_BATCHES'].to_i
    [Spree::OptionValue, Spree::Product].each do|klass|
      begin
        record = klass.last
        syncing_status = nil
        if File.exists?(SYNCING_STATUS_FILE)
          File.open(SYNCING_STATUS_FILE,'r'){|f| syncing_status = f.read.strip }
        end
        if syncing_status == klass.to_s
          puts "> Another process already running to sync #{klass}"
        elsif record.nil?
          puts "> No more records of #{klass}"
          klass.es.rebuild_index!
        else
          latest_time = ENV['START_TIME'] ? Time.parse(ENV['START_TIME']) : nil
          latest_time ||= ENV['START_TIME_IN_RUBY'].present? ? eval(ENV['START_TIME_IN_RUBY']) : nil
          unless latest_time
            index_latest = klass.es.search(query:{ match_all:{}}, size:1, sort:{created_at:'desc'}).records.first
            index_latest ||= klass.first
            latest_time = index_latest.created_at
          end

          t = klass.table_name
          query = record.respond_to?(:deleted_at) ? 
            klass.with_deleted.where("#{t}.created_at >= ? or #{t}.updated_at >= ? or #{t}.deleted_at >= ?", latest_time, latest_time, latest_time) :
            klass.where("#{t}.created_at >= ? or #{t}.updated_at >= ?", latest_time, latest_time)
          puts '#' * 60
          puts "Total #{query.count}, #{klass} starting #{latest_time}"
          File.open(SYNCING_STATUS_FILE,'w'){|f| f.write(klass.to_s); syncing_status = klass.to_s; }

          #################
          index = 1
          query.in_batches(of: 50, start: 1) do|batch_q|
            batch_q = batch_q.includes_for_indexing if klass.respond_to?(:includes_for_indexing)
            puts "| batch_q #{batch_q.to_sql}"
            batch_q.each do|r|
              puts "#{index} ---------------------" if index % 100 == 0
              r.es.update_document
              index += 1
            end
            sleep(SLEEP_BETWEEN_BATCHES) if SLEEP_BETWEEN_BATCHES > 0
          end
          sleep(10)
        end
      rescue Exception => index_e
        puts "--------------------\n** Error syncing #{klass}: #{index_e.message}"
        puts index_e.backtrace.join("\n  ")
      ensure
        File.open(SYNCING_STATUS_FILE,'w'){|f| f.write(''); syncing_status = nil; }
      end
    end # each class

    end_time = Time.now
    puts "--------------------------------\n Took #{(end_time - start_time) / 1.minute} minutes"
  end

  desc 'Queries stats of how in sync is the products ES index'
  task :validate_products_index => [:environment ]do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    # Iterate over every non-deleted product in DB, and count if indexable?
    mailer = ARGV.shift
    puts "Validate Products Index w/ #{mailer}"

    another = ARGV.shift
    puts "Another arg #{another}"
    #################
    index = 1


  end

end