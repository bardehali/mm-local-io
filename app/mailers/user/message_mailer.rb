class User::MessageMailer < ApplicationMailer

  def new_message(message)
    @message = message
    @user = @message.recipient
        
    @url = URI.join( host, '/login')
    
    m = mail(to: @user.email, 
        subject: I18n.t('message.name_have_new_message_from_ioffer', username: @user.try_display_name)
      )
    m.from = "iOffer Helper <#{m.from.first}>"
    m
  end

end
