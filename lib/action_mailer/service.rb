module ActionMailer::Service
  
  ##
  # @mail [ActionMailer::Parameterized::MessageDelivery] created by some Mailer
  # @return [Mail::Message]
  def make_mail_object(mail)
    # smtp
    text_part = mail.parts.find{|part| part['content-type'].to_s =~ /text\/plain/i } 
    html_part = mail.parts.find{|part| part['content-type'].to_s =~ /text\/html/i }
    mail_object = Mail.new do
      text_part do
        body text_part.body.to_s
      end
      html_part do
        content_type 'text/html;charset = UTF-8'
        body html_part.body.to_s
      end
    end
    mail_object.to = mail['to'].to_s,
    mail_object.from = mail['from'].to_s,
    mail_object.subject = mail.subject
    mail_object
  end

  ##
  # @yield [Net::SMTP]
  def start_smtp_connection(&block)
    begin
      smtp = make_smtp_connection
      yield smtp
    ensure
      smtp.finish if smtp
    end
  end

  def make_smtp_connection
    config = Rails.application.config.action_mailer.smtp_settings
    smtp = Net::SMTP.new(config[:address], config[:port] )
    
    # Possible error. ArgumentError: SMTPS and STARTTLS is exclusive
    # smtp.enable_starttls if config[:enable_starttls_auto]
    smtp.enable_tls if config[:tls]
    smtp.start( config[:domain], config[:user_name], config[:password], config[:authentication] )
    smtp
  end

end