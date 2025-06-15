module User
  module MessagesHelper
    extend ActiveSupport::Concern
    
    ##
    # Instead of full Ruby class scope, like User::NewOrder, put short human form like 
    # new_order.
    def available_user_message_type_ids(sender, recipient)
      if sender.admin?
        %w[]
      end
    end

    def load_user_notifications(other_query_conditions = nil)
      other_query_conditions ||= { last_viewed_at: nil }
      Spree::User.logger.debug "| load_user_notifications w/ #{other_query_conditions} for recipient #{spree_current_user}"
      return [] unless spree_current_user
      unless @user_notifications
        @user_notifications = User::Message.includes(:sender).where(recipient_user_id: spree_current_user.id).where(other_query_conditions).order('level desc, id desc').limit(10)
      end
      @user_notifications
    end

    def load_user_notifications_from_admin
      load_user_notifications( { sender_user_id: Spree::User.admins.collect(&:id) } )
    end
  end
end