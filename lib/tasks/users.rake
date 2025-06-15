require 'csv'
require 'mail'
require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

require File.join(Rails.root, 'lib/action_mailer/service')
include ActionMailer::Service

require File.join(Rails.root, 'lib/spree/service/users_task_helper')
include Spree::Service::UsersTaskHelper

require File.join(Rails.root, 'lib/spree/service/email_campaign_service')






####################################
# Tasks

namespace :users do
  ##
  # rake users:import_ioffer_from_csv file_path
  # Fields can be:
  #   User or user_id or seller,Email,Location,Member Since,Phone,Registration,Name,GMS,TRX,Positive,Negative,Rating Score
  task :import_ioffer_from_csv => [:environment] do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    csv_file = ARGV.shift
    puts "CSV file: #{csv_file}"
    puts '=' * 60

    DRY_RUN = ENV['DRY_RUN']
    DEBUG = ENV['DEBUG']
    MAX_ROWS = (ENV['MAX_ROWS'] || ENV['LIMIT'] ).to_i
    OFFSET = ENV['OFFSET'].to_i

    headers = File.open(csv_file).readline.strip.split(',')
    headers_mapping = make_headers_mapping(USER_ATTRIBUTE_RULES, headers)

    CSV.parse(File.read(csv_file), headers: true).each_with_index do |csv_row, row_index|
      next if (OFFSET > 0 && row_index + 1 < OFFSET)
      puts ' .. %d %s' % [row_index, '-' * 40 ] if row_index % 100 == 0
      if MAX_ROWS > 0 && row_index + 1 >= OFFSET + MAX_ROWS
        break
      end

      begin
        row = csv_row.to_hash
        user_attr = make_user_attributes(row, headers_mapping)
        ioffer_user = ::Ioffer::User.find_or_initialize_by( username: user_attr[:username] ) do|u|
          u.password = 'test1234'
        end
        ioffer_user.attributes = user_attr.except(:username)
        ioffer_user.email = "#{user.username}@ioffer.com" if user.email.blank?
        if DEBUG && (ioffer_user.valid? || DEBUG) # force to validate & normalize
          puts '-' * 40
          puts ioffer_user.attributes.as_json 
        end
        unless DRY_RUN
          ioffer_user.save
          ioffer_user.reset_password_token!
          ioffer_user.convert!
        end
        puts '%5s | %s' % [ (user.try(:id) || '').to_s, user.username ]

      rescue Exception => e
        puts "** #{e.message}\n" + e.backtrace.join("\n")
      end
    end
  end

  desc 'Given a YAML w/ hash of username => item counts, update respective records'
  task :import_items_counts => [:environment] do
    h = YAML::load_file( File.join(Rails.root, 'db/usernames_to_items_counts.yml'))
    h.each_pair do|username, items_count|
      puts '%30s | %d' % [username, items_count]
      User.where(username: username).update(items_count: items_count)
    end
  end

  
  task :export_ioffer_seller_signups => [:environment] do
    #ARGV.shift
    #csv_file_path = ARGV.shift
    #io = csv_file_path.present? ? 
    limit = ENV['LIMIT'].to_i
    all = ENV['ALL']

    query = Ioffer::User.where("created_at > ?", Ioffer::User::END_OF_IMPORTED_USERS).order('id desc')
    query = query.where('last_email_at is null') unless all.to_s == 'true'
    query = query.limit(limit) if limit > 0
    headers = %w(username email sign_up_time sign_up_ip client_id session_cookie)
    headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
    $stdout.puts headers_row.to_s
    query.each do|u|
      spree_user = Spree::User.find_by_username u.username
      cookies_h = u.cookies.present? ? eval(u.cookies) : {}
      col_values = [u.username, u.email, u.created_at.to_s(:db), u.ip, 
        cookies_h['client_id'].to_s,
        (cookies_h['token'] || cookies_h['_ioffer_landing_session'] ).to_s ]
      row = CSV::Row.new(headers, col_values)
      puts row.to_s
    end
  end

  task :export_signed_in_users => [:environment] do
    limit = ENV['LIMIT'].to_i
    all = ENV['ALL']

    supplier_admin = Spree::User.find_by(email:'supplier_admin@example.com')
    query = Spree::User.where('last_sign_in_at IS NOT NULL AND spree_users.id NOT IN (?)', 
      [Spree::User.admin.first.id, supplier_admin&.id].compact )
    query = query.limit(limit) if limit > 0
    headers = %w(id username email sign_up_time last_login_time last_login_ip country is_legacy gms txns_count products_posted products_adopted last_email last_email_return)
    headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
    $stdout.puts headers_row.to_s
    query.all.each do|u|
      col_values = [u.id, u.username, u.email, u.created_at.to_s, u.last_sign_in_at.to_s, u.last_sign_in_ip,
        RequestLog.where(user_id: u.id).last&.country || u.country, u.legacy? || false, u.ioffer_user&.gms,
        u.ioffer_user&.transactions_count, u.products.count, u.adopted_products_count,
        u.last_email_at.to_s, u.request_logs.on_reset_password.last&.created_at.to_s
      ]
      row = CSV::Row.new(headers, col_values)
      $stdout.puts row.to_s
    end
  end

  task :recalculate_stats => [:environment] do
    trap_signal_and_exit
    convert_env_variables

    puts '#' * 60
    puts '# users:recalculate_stats'
    print_beginning_info

    query = Spree::User.sellers
    puts "Total of #{query.count} sellers"
    batch_index = 0
    query.includes(:user_stats).find_in_batches do|batch| 
      batch.each do|u| 
        r = u.recalculate_user_stats! 
        r = u.calculate_stats! 
        if @debug && r.values.find{|v| v > 0 }
          puts "%6d | %30s | %s" % [u.id, u.username || u.email, r.as_json]
        end
      end
      batch_index += 1
      puts "Batch #{batch_index} at #{Time.now} -----------------------------"
    end
    
    puts '#' * 60
    print_ending_info
  end
  
end