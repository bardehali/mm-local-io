require 'open-uri'

module User
  class MessagesController < Spree::Admin::BaseController
    inherit_resources

    include ::ControllerHelpers::ImageUploaderHelper

    helper 'spree/admin/navigation'
    layout 'spree/layouts/admin'

    skip_before_action :authorize_admin, except: [:new, :edit, :update, :create]
    skip_before_action :authorize_seller!
    before_action :load_data, only: [:new, :create, :index]
    before_action :set_sender, only: [:create]

    ##
    # Given parameter ?goto=y can try to go to message's path
    def show
      authorize! :read, resource
      resource.update(last_viewed_at: Time.now) if resource.last_viewed_at.nil? && !resource.recipient_must_respond?
      goto_path = params[:goto]
      if goto_path.present?
        goto_path = resource.path if goto_path.size < 2
      end
      if goto_path.present? 
        redirect_to goto_path
      else
        super
      end
    end

    def create
      next_url = params[:next_url].present? ? params[:next_url] : 
        new_user_message_path(recipient_user_id: resource.recipient_user_id, t: Time.now.to_i)
      super do|format|
        format.html { redirect_to next_url }
      end
    end

    ##
    # params[:image] needs to match @message.image.image_id
    def image
      @message = resource
      render_image(@message&.image)
    end

    def thumb
      @message = resource
      render_image(@message&.image, :thumb)
    end

    protected

    def collection
      logger.debug "| collect_name: #{self.resources_configuration[:self][:collection_name]}"
      logger.debug "| end_of_association_chain: #{end_of_association_chain}"
      return @messages if @messages 
      return [] if spree_current_user.nil?
      @messages = super
      @messages = @messages.includes(:sender, :recipient).where(recipient_user_id: spree_current_user.id).
        order("level DESC, #{User::Message.table_name}.id DESC")
      if params[:status] == 'all'
      elsif params[:status] == 'viewed'
        @messages = @messages.where('last_viewed_at IS NOT NULL')
      else
        @messages = @messages.not_viewed
      end
      @messages
    end

    ##
    # @recipient if recipient_user_id given
    def load_data
      resource_p = params[resource_instance_name.to_sym] ||= {}
      user_id = params[:recipient_user_id] || resource_p[:recipient_user_id]
      logger.debug "| user_id: #{user_id} while resource_instance_name #{resource_instance_name}"
      @recipient ||= user_id ? Spree::User.includes(:role_users).find_by(id: user_id) : nil
      @messages_to_recipient = User::Message.where(sender_user_id: spree_current_user&.id, recipient_user_id: @recipient.id).order('id desc').page(params[:page] || 1) if @recipient
    end

    def set_sender
      build_resource.sender_user_id = spree_current_user&.id
      logger.debug "| resource: #{resource.attributes}"
      logger.debug "| valid? #{resource.valid?}, errors: #{resource.errors.full_messages}"
    end

    ##
    # inherited_resources overrides

    def permitted_params
      params.permit(:authenticity_token, 
        :user_message => [:type, :recipient_user_id, :comment, :record_type, :record_id, :group_name, :parent_message_id])
    end

    def resource_instance_name
      'user_message'
    end

    def resource_collection_name
      'user_messages'
    end

  end
end