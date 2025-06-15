class ApplicationMailer < ActionMailer::Base
  include Spree::Core::Engine.routes.url_helpers
  include Spree::BaseMailerDecorator
  include Spree::BaseMailerDecorator::HelperMethods

  helper Spree::BaseMailerDecorator::HelperMethods

  default from: 'iOffer Marketplace <noreply@mail.ioffer.com>'
  layout 'mailer'

  
  def send_via_api(message, campaign_name = 'iOffer Campaign via API', &block)
    SibApiV3Sdk.configure do |config|
      config.api_key['api-key'] = ENV['SENDINBLUE_API_KEY'] || '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'
    end
    api_instance = SibApiV3Sdk::EmailCampaignsApi.new

    body = mail.body.parts.find{|part| part.respond_to?(:content_type) && part.content_type =~ /\btext\/html\b/ }
    body ||= mail.body.parts.last

    # Define the campaign settings \
    email_campaign = {
      "name"=> campaign_name,
      "subject"=> message.subject,
      "sender"=> { "name"=> from_address.address.name || 'iOffer CS', "email"=> from_address.address},
      "type"=> "classic",
      
      # Content that will be sent\
      "htmlContent"=> body,

      # Select the recipients\
      "recipients"=> { "listIds"=> [3] },

      # Schedule the sending in one hour\
      "scheduledAt"=> 1.minute.since
    }
    # Make the call to the client\
    begin
      result = api_instance.create_email_campaign(email_campaign)
      p result
      yield result if block_given?
    rescue SibApiV3Sdk::ApiError => e
      puts "Exception when calling EmailCampaignsApi->create_email_campaign: #{e}"
    end
  end
end