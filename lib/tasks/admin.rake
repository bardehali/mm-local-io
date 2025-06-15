require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper
require 'net/http'
require 'uri'

namespace :admin do

  desc "Check if there are no transactions in the last hour and notify once"
  task check_transactions: :environment do
    last_transaction = Spree::Order.where("completed_at >= ?", 15.minutes.ago).order(completed_at: :desc).first
    notification_file = Rails.root.join('tmp', 'last_notification_time.txt')

    if last_transaction.nil?
      # Send email notification
      ApplicationMailer.new.mail(
        from: 'noreply@mail.ioffer.com',
        to: ['neilhussain.me@gmail.com', '6109054386@txt.att.net'], # Add as many emails as needed
        subject: 'No Transactions in the Last Hour',
        body: "There have been no transactions in the last hour. Consider doing a full reset."
      ).deliver

      # Update the last notification time
      begin
        File.write(notification_file, Time.now.to_i)
      rescue => e
        Rails.logger.error "Failed to write to notification file: #{e.message}"
      end
    else
      puts "Last transaction was at #{last_transaction.completed_at}"

      # Reset notification time if a transaction occurred
      File.delete(notification_file) if File.exist?(notification_file)
    end
  end


  desc "Simple test task"
  task simple_test: :environment do
    File.open(Rails.root.join('tmp', 'simple_test.log'), 'a') do |f|
      f.puts "Cron job executed at #{Time.now}"
    end
  end

  desc "Check if there are no transactions in the last hour and notify once"
   task check_transactions_notify: :environment do
     last_transaction = Spree::Order.where("completed_at >= ?", 15.minutes.ago).order(completed_at: :desc).first
     notification_url = URI.parse("https://ioffer.com/958asfa3428/notrx")

     if last_transaction.nil?
       # Make the HTTP request
       begin
         response = Net::HTTP.get_response(notification_url)
         if response.is_a?(Net::HTTPSuccess)
           Rails.logger.info "Notification request sent successfully."
         else
           Rails.logger.error "Failed to send notification request. HTTP Response Code: #{response.code}"
         end
       rescue => e
         Rails.logger.error "Failed to send notification request: #{e.message}"
       end
     else
       puts "Last transaction was at #{last_transaction.completed_at}"
     end
   end

end
