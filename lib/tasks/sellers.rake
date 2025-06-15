require 'csv'
require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

require File.join(Rails.root, 'lib/spree/service/users_task_helper')
include Spree::Service::UsersTaskHelper

namespace :sellers do
  task :update_seller_ranks => [:environment] do
    start_time = Time.now
    puts "==============================\n#{start_time.to_s(:db) }"
    dry_run = ENV['DRY_RUN']
    query = Spree::User.where(nil)
    query = apply_more_to_query(query)
    puts "query: #{query.to_sql}"

    record_count = query.count
    puts "Total users: #{record_count}"
    puts "dry run? #{dry_run}"

    query.includes(:spree_roles, :ioffer_user, 
        store:{ store_payment_methods:[:payment_method] } ).find_in_batches do|batch| 
      batch.each do|u| 
        r = u.calculate_seller_rank 
        puts "%6d | %30s | %10d" % [u.id, u.username || u.email, r] if r > 0
        unless dry_run
          u.update(seller_rank: r)
        end
      end
    end

    puts "==============================\n"
    total_mins = (Time.now - start_time) / 1.minute
    puts "Done at: #{Time.now}, took #{total_mins} mins for #{record_count} users, so avg #{record_count / total_mins.to_f} per min"
    
  end

    ##
  # Fields: ID, Username, Email, TRX Count, Days Since Login, Sign up time, User Role, Last_Email_Time, Paypal Email, Country, IP
  task :export_sellers => [:environment] do
    output = find_or_default_output
    where_cond = ENV['CUSTOM_WHERE_CONDITION']
    custom_join = ENV['CUSTOM_JOIN']
    skip_test_or_fake_users = ENV['SKIP_TEST_OR_FAKE_USERS'].to_s != 'false'

    headers = ['ID', 'Username', 'Email', 'TRX Count', 'Days Since Login', 
      'Last Active time', 'User Role', 'Last Email Time', 'Paypal Email', 'Country', 'IP']
    headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
    output.puts headers_row.to_s

    paypal = Spree::PaymentMethod.paypal

    q = Spree::User.includes(:spree_roles, :request_logs)
    q = q.joins(custom_join) if custom_join.present?
    q = q.where(where_cond) if where_cond.present?
    # logger.debug "export_sellers q: #{q.to_sql}"

    q.distinct.in_batches(of: 50, start: 0) do|relation|
      relation.each do|u|
        next if u.admin? || (skip_test_or_fake_users && u.test_or_fake_user?)
        txn_q = Spree::Order.complete.where(seller_user_id: u.id)
        txn_q = txn_q.where(where_cond) if where_cond.present?
        last_sign_in_at = u.last_active_at || u.request_logs.on_sign_in.order('id desc').first&.created_at || u.current_sign_in_at
        col_values = [u.id, u.username, u.email, txn_q.count,
          last_sign_in_at ? ((Time.now - last_sign_in_at) / 1.day.to_f).round : '',
          u.created_at.to_s, u.spree_roles.collect(&:name).join(', '),
          u.last_email_at&.to_s, 
          u.fetch_store.store_payment_methods.find{|spm| spm.payment_method_id == paypal.id }&.account_id_in_parameters,
          u.country, u.current_sign_in_ip || u.last_sign_in_ip
        ]
        row = CSV::Row.new(headers, col_values)
        output.puts row.to_s
      end
    end
  end

end