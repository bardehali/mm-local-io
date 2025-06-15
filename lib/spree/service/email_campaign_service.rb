require File.join(Rails.root, 'lib/action_mailer/service')
require File.join(Rails.root, 'lib/spree/service/users_task_helper')

class Spree::Service::EmailCampaignService
  include ActionMailer::Service
  include Spree::Service::UsersTaskHelper

  attr_accessor :dry_run, :debug, :limit, :offset

  def initialize(options = {})
    self.dry_run = options[:dry_run]
    self.debug = options[:debug]
    self.limit = options[:limit]
    self.offset = options[:offset]
  end

  # Create the EmailCampaign w/ same user_list name, and populate deliveries.
  # @return [Spree::EmailCampaign]
  def create(name, csv_file)
    puts "User list and campaign name: #{name}"
    puts "CSV file: #{csv_file}"
    puts '=' * 60

    user_list = Spree::UserList.find_or_create_by(name: name)
    campaign = Spree::EmailCampaign.find_or_create_by(name: name) do|c|
      c.user_list_id = user_list.id
    end

    headers = File.open(csv_file).readline.strip.split(',')
    headers_mapping = make_headers_mapping(USER_ATTRIBUTE_RULES, headers)

    CSV.parse(File.read(csv_file), headers: true).each_with_index do |csv_row, row_index|
      row = csv_row.to_hash
      user_attr = make_user_attributes(row, headers_mapping)
      if (user = Spree::User.find_by(id: user_attr[:id].to_i) )
        puts '%7d | %s' % [user.id, user.email]
        unless dry_run
          user_list.user_list_users.find_or_create_by(user_id: user.id)
        end
      else
        puts 'row %d | user %s, email %s NOT FOUND' % [row_index, user_attr[:id], user_attr[:email]]
      end
    end

    campaign.populate_deliveries unless dry_run

    campaign
  end

  # Delivery other not delivered.  The @mailer_class and @mailer_method together would represent some like 
  # 'AdvertiserOnboardingMailer.advertiser_login_list'.  Will attempt to use global SMTP connection; 
  # but if failed being nil, would use individual deliver call.
  # @mailer_class [Class of ActionMailer]
  # @mailer_method [String, method name of @mailer_class]
  def deliver(email_campaign, mailer_class, mailer_method)
    puts "==============================\n#{mailer_class} #{mailer_method}"
    puts "Email campaign: #{email_campaign.name}"
    puts "user list: #{email_campaign.user_list.name}"
    puts "deliveries: total #{email_campaign.deliveries.count} (#{email_campaign.deliveries.delivered.count} delivered)"
    puts "limit: #{limit}, dry_run? #{dry_run}"
  
    emails = []

    index = 0
    consecutive_errors = 0
    query = email_campaign.deliveries.not_delivered
    query = query.limit(limit) if limit.to_i > 0
    start_smtp_connection do|smtp|
      query.each do|d|
        index += 1
        begin
          ioffer_user = d.user.ensure_ioffer_user!
          puts '%d at %s %s' % [index, Time.now.to_s, '-' * 40] if index % 50 == 0
          puts '%3d | %30s | %s' % [index, d.user.username, d.email]
          mail = mailer_class.with(user: d.user).send(mailer_method.to_sym)
          puts 'Subject: %s' % [mail.subject]

          bounces_count = EmailBounce.where(email: u.email).count
          if bounces_count > 0
            puts ('*' * 40) + " Email #{d.user.email} bounced #{bounces_count > 0}"
            next
          end
          unless dry_run
            ioffer_user.update(email_trial_count: ioffer_user.email_trial_count.to_i + 1)

            # if smtp
            #  smtp.send_message make_mail_object(mail).to_s, mail['from'].to_s, mail['to'].to_s
            #else
              mail.deliver
            # end

            ioffer_user.update(last_email_at: Time.now)
            d.user.update(last_email_at: Time.now)
            d.update(delivered_at: Time.now, trial_count: d.trial_count.to_i + 1)

          end
          consecutive_errors = 0

        rescue Interrupt
          confirm_to_exit
        rescue Exception => email_e
          puts "** Problem sending email: #{email_e.message}\n#{email_e.backtrace.join("\n") }"
          puts email_e.backtrace.join("  \n") unless Rails.env.development?
          if email_e.message =~ /(close\s+|closing\s+)?connection(\s+problem)?/i
            begin
              smtp.finish if smtp
            rescue
            end
            smtp = make_smtp_connection

          elsif email_e.message =~ /quota\s+exceeded|too\s+many\s+(login\s+)?attempts/i
            puts "Sent #{index}"
            puts "Need to exit .........................."
            sleep(5)
            exit!
          end
          consecutive_errors += 1
          if consecutive_errors > 5
            puts "Consecutive #{consecutive_errors} errors"
            puts "Need to exit .........................."
            sleep(5)
            exit!
          end
        end

        sleep( 3 + rand(5) )
        sleep( 30 + rand(60) ) if index % 10 == 0
      end # query.each
    end
  end
end