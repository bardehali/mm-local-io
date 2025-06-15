require 'csv'
require 'mail'
require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

require File.join(Rails.root, 'lib/action_mailer/service')
include ActionMailer::Service

require File.join(Rails.root, 'lib/spree/service/users_task_helper')
include Spree::Service::UsersTaskHelper

require File.join(Rails.root, 'lib/spree/service/email_campaign_service')



##
# Optional argument could be a CSV file that limits which users.
# Checking of email delivery status is still on Ioffer::User table, 
# but password reset will be called to associated Spree::User
# Environment variables checked: 
#   DRY_RUN: true or some value would skip delivering email and DB update
#   EMAIL_ALL: at default deliver only those User.should_get_email; if true would email any
#   LIMIT: if set, would limit how many to send
# @which_email [String] the mailer method
def deliver_batch_emails(which_email)
  puts "==============================\nWhich email? #{which_email}"
  ARGV.each { |a| task a.to_sym do ; end }
  ARGV.shift
  csv_file = ARGV.shift
  puts "CSV file: #{csv_file}"
  puts '=' * 60
  dry_run = ENV['DRY_RUN']
  email_all = ENV['EMAIL_ALL']
  limit = ENV['LIMIT']
  offset = ENV['OFFSET']

  emails = []
  if csv_file.present? && File.exists?(csv_file)
    headers = File.open(csv_file).readline.strip.split(',')
    headers_mapping = make_headers_mapping(USER_ATTRIBUTE_RULES, headers)
    CSV.parse(File.read(csv_file), headers: true).each_with_index do |csv_row, row_index|
      row = csv_row.to_hash
      user_attr = make_user_attributes(row, headers_mapping)
      emails << user_attr[:email]
    end
  end

  query = Ioffer::User.where('email IS NOT NULL')
  query = query.should_get_email unless email_all
  query = query.where(email: emails) if emails.size > 0
  query = query.no_email_sent unless emails.present?
  query = query.limit(limit) if limit.to_i > 0
  query = query.offset(offset) if offset.to_i > 0
  puts "Total count of users #{query.count}"
  puts "query: #{query.to_sql}\n---------------------------------"
  start_smtp_connection do|smtp|
    index = 0
    query.each do|ioffer_user|
      index += 1
      begin
        user = ioffer_user.convert!
        puts '%d at %s %s' % [index, Time.now.to_s, '-' * 40] if index % 50 == 0
        puts '%3d | %30s | %s' % [index, user.username, user.email]
        mail = AdvertiserMailer.with(user: user).send(which_email.to_sym)
        puts 'Subject: %s' % [mail.subject]
        unless dry_run
          ioffer_user.update(email_trial_count: ioffer_user.email_trial_count.to_i + 1)
          
          smtp.send_message make_mail_object(mail).to_s, mail['from'].to_s, mail['to'].to_s

          ioffer_user.update(last_email_at: Time.now)
          user.update(last_email_at: Time.now)
          sleep( rand(5) )
        end
      rescue Interrupt # => interupt_e
        confirm_to_exit
      rescue Exception => email_e
        puts "** Problem sending email: #{email_e.message}\n#{email_e.backtrace.join("\n") }"
        puts email_e.backtrace.join("  \n") unless Rails.env.development?
        if email_e.message =~ /quota\s+exceeded/i
          puts "Need to exit .........................."
          sleep(5)
          exit!
        end
      end
    end # query.each
  end
end

####################################################
# Tasks

namespace :email do

  task :deliver_test_email => [:environment] do
    start_smtp_connection do|smtp|
      user = Spree::User.last
      mail = AdvertiserMailer.with(user: user).advertiser_login_list
      r = smtp.send_message make_mail_object(mail).to_s, mail['from'].to_s, mail['to'].to_s
      puts " > sent status #{r}"
    end

    # ------------------
    # Create a campaign\
    # ------------------
    # Include the Sendinblue library\
    # Instantiate the client\
  end

  ##
  # Time string in format '5/14/2020 10:45:38' would be invalid.
  REVERSED_YEAR_IN_DATE_REGEXP = /\A(\d{1,2})\/(\d{1,2})\/(\d{4})(\s*.+)?/

  ##
  # Syntax: rake email:import_bounces "/filepath/sellers-4300-15000.csv"
  task :import_bounces => [:environment] do
    ARGV.shift
    csv_file = ARGV.shift
    puts "Import from, exist? #{File.exists?(csv_file)}: #{csv_file}"
    
    dry_run = ENV['DRY_RUN']
    emails = Set.new
    CSV.parse(File.read(csv_file), headers: true).each do |csv_row|
      next if emails.include?(csv_row['email'])
      delivery_time_s = csv_row['delivery_time'] || csv_row['delivered_at']
      if (m = delivery_time_s.match(REVERSED_YEAR_IN_DATE_REGEXP) )
        delivery_time_s = "#{m[3]}/#{m[1]}/#{m[2]}#{m[4]}"
      end
      delivery_time = Time.parse(delivery_time_s)
      bounce = EmailBounce.find_or_initialize_by(email: csv_row['email'], delivered_at: delivery_time )
      bounce.subject = csv_row['subject']
      bounce.reason = csv_row['reason'] || csv_row['error']
      emails << bounce.email
      bounce.save unless dry_run
    end.class
    puts "-------------------\nfound #{emails.size} and #{emails.uniq.size} unique"

  end
end

namespace :users do
  ##
  # Send seller_return email to every user
  
  task :seller_return_email => [:environment] do
    deliver_batch_emails('seller_return')
  end

  task :incomplete_seller_email => [:environment] do
    deliver_batch_emails('incomplete_seller')
  end

  task :advertiser_login => [:environment] do
    deliver_batch_emails('advertiser_login_list')
  end

  #################################
  # Different from :import_ioffer_email_campaign, as this is for Spree::User
  # Syntax: rake users:create_user_list_and_email_campaign user_list_name csv_file
  task :create_user_list_and_email_campaign => [:environment] do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    name = ARGV.shift
    csv_file = ARGV.shift
    puts "User list and campaign name: #{name}"
    puts "CSV file: #{csv_file}"
    puts '=' * 60

    service = Spree::Service::EmailCampaignService.new(dry_run: ENV['DRY_RUN'] )
    service.create(name, csv_file)
  end

  ##################################
  # Syntax: rake users:deliver_email_campaign Mailer.email_method campaign_name_or_id
  # If campaign_name_or_id not provided, would be last.
  task :deliver_email_campaign => [:environment] do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    mailer_class_and_method = ARGV.shift # 'AdvertiserOnboardingMailer.advertiser_login_list'
    if mailer_class_and_method.blank?
      raise ArgumentError.new("Missing required Mailer and template such as AdvertiserOnboardingMailer.advertiser_login_list")
    end
    mailer_class_name, which_email = mailer_class_and_method.split(/[\.\#]/)
    mailer_class = mailer_class_name.constantize

    email_campaign_arg = ARGV.shift;
    email_campaign = nil
    if email_campaign_arg.present?
      email_campaign = email_campaign_arg.to_s =~ /\A\s*\d+\s*\Z/ ? 
        Spree::EmailCampaign.find(email_campaign_arg.to_i) : 
        Spree::EmailCampaign.find_by(name: email_campaign_arg)
    end
    email_campaign ||= Spree::EmailCampaign.last

    service = Spree::Service::EmailCampaignService.new(dry_run: ENV['DRY_RUN'], limit: ENV['LIMIT'])
    service.deliver(email_campaign, mailer_class, which_email)
  end # deliver_email_campaign

  ##
  # Syntax: rake users:import_ioffer_email_campaign "/filepath/sellers-4300-15000.csv"
  task :import_ioffer_email_campaign => [:environment] do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    csv_file = ARGV.shift
    puts "Import from, exist? #{File.exists?(csv_file)}: #{csv_file}"
    
    username_col = ENV['USERNAME_COL'] || 'Username'
    dry_run = ENV['DRY_RUN']
    initialize_method = dry_run ? :new : :create
    campaign_name = ENV['CAMPAIGN_NAME'] || File.basename(csv_file).gsub(/(\.\w+)\Z/, '')
    
    usernames = []
    CSV.parse(File.read(csv_file), headers: true).each do |csv_row|
      usernames << csv_row[username_col]
    end.class
    puts "got #{usernames.size} usernames"
    puts "  and found #{Ioffer::User.where(username: usernames).count} Ioffer::User"
    puts "#{initialize_method} w/ name #{campaign_name}"

    Ioffer::User.where(username: usernames).each do|iu|
      unless dry_run
        iu.convert_to_spree_user!
      end
    end

    user_list = Spree::UserList.send(initialize_method, name: campaign_name)
    Spree::User.where(username: usernames).each do|u| 
      user_list.user_list_users.send( dry_run ? :find_or_initialize_by : :find_or_create_by, user_id: u.id)
    end

    campaign = Spree::EmailCampaign.send(initialize_method, name: campaign_name, user_list_id: user_list.id)
  end
end