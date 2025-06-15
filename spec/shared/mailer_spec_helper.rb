module MailerSpecHelper

  def is_delivery_method_test?
    Rails.configuration.action_mailer.delivery_method == :test
  end
  ##
  # Find through ActionMailer::Base.deliveries for matches email of 
  # #{@matching_class}.#{@mailer_method} with matching from, to, and subject
  def check_mailer_deliveries(mailer_class, mailer_method, variables = {}, &block)
    expected_m = mailer_class.with(variables).send(mailer_method.to_sym)
    if is_delivery_method_test?
      matched_m = ActionMailer::Base.deliveries.find do|delivery|
        # some email could have multiple mime parts (text, HTML)
        some_part = delivery.body.respond_to?(:parts) ? delivery.body.parts[0] : delivery.body

        %w(from to subject).all? do|a|
          delivery.send(a.to_sym) == expected_m.send(a.to_sym)
        end
      end
      expect(matched_m).not_to be_nil
      yield matched_m if block_given?
    end # delvery_method == :test
  end


  ##
  # Check mail settings whether dynamically set just before delivery.
  # Check there's one email sent to @user.
  # @mail [Mail::Message]
  # @expected_email_service_name [String] like 'gmail', 'aliyun'
  def check_mail_settings(user, mail, expected_email_service_name)
    wanted_settings = Rails.application.config.respond_to?(:dynamic_smtp_settings) ?
      Rails.application.config.dynamic_smtp_settings[ expected_email_service_name ] : nil
    # some revision might not have dynamic_smtp_settings
    if wanted_settings && (mail.delivery_method.is_a?(Mail::SMTP) || mail.delivery_method.is_a?(Mail::TestMailer) )
      smtp_settings = mail.delivery_method.settings
      expect(smtp_settings[:address]).to eq( wanted_settings[:address] )
      expect(mail.from.include?( wanted_settings[:from] || wanted_settings[:user_name] ) ).to be_truthy
    end
    if mail.delivery_method.is_a?(Mail::TestMailer)
      last_mail_sent = ActionMailer::Base.deliveries.reverse.find do|m|
        m.to.collect(&:to_s).include?(user.email)
      end
      expect(last_mail_sent).not_to be_nil

      if user.seller?
        comment = 'More words to say about you'
        msg_to_seller = User::Message.create(sender_user_id: Spree::User.fetch_admin.id, 
          recipient_user_id: user.id, comment: comment)
        last_seller_mail_sent = ActionMailer::Base.deliveries.reverse.find do|m|
          m.to.collect(&:to_s).include?(user.email) && I18n.t('message.name_have_new_message_from_ioffer', username: user.try_display_name)
        end
        expect(last_seller_mail_sent).not_to be_nil
      end
    end
  end

end