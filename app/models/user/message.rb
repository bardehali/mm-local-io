class User::Message < ApplicationRecord
  include WithOtherRecord
  include Rails.application.routes.url_helpers
  include Spree::Core::Engine.routes.url_helpers

  self.table_name = 'user_messages'

  ARCHIVE_PREVIOUS_MESSAGES = false

  ALLOW_TO_UPLOAD_IMAGE = true

  INITIAL_ORDER_LEVEL = 100
  ORDER_LEVEL = 500
  COMPLAINT_LEVEL = 1000
  ADMIN_LEVEL = 2000
  LEVELS = {
    1 => 'Normal', ORDER_LEVEL => 'Order', COMPLAINT_LEVEL => 'Complaint'
  }

  acts_as_paranoid

  alias_attribute :user_id, :recipient_user_id

  if ALLOW_TO_UPLOAD_IMAGE
    attr_reader :image
    mount_uploader :image, ::ImageUploader
  end

  validates_presence_of :sender_user_id, :recipient_user_id

  belongs_to :sender, foreign_key: 'sender_user_id', class_name:'Spree::User'
  belongs_to :recipient, foreign_key: 'recipient_user_id', class_name:'Spree::User'

  has_one :parent_message, foreign_key:'parent_message_id', class_name:'User::Message'

  scope :not_viewed, -> { where('last_viewed_at is null') }
  scope :order_comments, -> { where('level BETWEEN ? AND ?', ORDER_LEVEL, COMPLAINT_LEVEL - 1) }
  scope :complaint_or_higher_level, -> { where('level >= ?', COMPLAINT_LEVEL) }

  before_create :set_defaults
  after_create :mark_viewed_to_previous_of_same_record!
  after_create :archive_previous_of_same_record! if ARCHIVE_PREVIOUS_MESSAGES
  after_create :schedule_to_send_email

  def self.group_name
    nil
  end

  def self.level
    1
  end

  ##
  # Short form w/ last segment of class name underscored.
  # Good for UI class naming.
  def type_id
    type.split('::').last.underscore
  end

  MISSING_TRANSLATION_REGEXP = /translation\s+missing/i

  ##
  # Exact retrieval of words from locale dictionary, in path of messages.subject.$type_id
  def subject
    local_s = type_id == 'message' ? '' : I18n.translate("message.#{type_id}.subject")
    local_s =~ MISSING_TRANSLATION_REGEXP ? type_id.titleize : local_s
  end

  INLINE_CODE_IN_STRING = /(#\{(\S+)\})/
  ##
  # Instead of plain text subject (from translate dictionary), evaluate
  # variables within to match method/attribute of this message.
  # Format: #{record.user.name}, same as inline code in String
  def subject_evaluated
    evaludate_inline(subject)
  end

  def comment_evaluated
    comment
  end

  def path
    path_s = I18n.translate("message.#{type_id}.path")
    path_s && path_s.match(MISSING_TRANSLATION_REGEXP).nil? ? evaludate_inline(path_s) : ''
  end

  # Dependent on dictionary's instruction value
  def instruction
    instr = I18n.translate("message.#{type_id}.instruction")
    instr && instr.match(MISSING_TRANSLATION_REGEXP).nil? ? instr : ''
  end

  def should_highlight?
    false
  end

  ##
  # Whether show only at beginning of discussion, and hide after.
  def initial_show_only?
    false
  end

  def show_only_to_recipient?
    false
  end

  def recipient_must_respond?
    false
  end

  ##
  # Specific message type, like NeedTrackingNumber, requires response of ProvidedTrackingNumber
  def must_respond_with_class
    nil
  end

  ##
  # Instead of class level, this would take precedence first if not nil.
  def overriding_level
    (sender_user_id == Spree::User.fetch_admin.id || sender&.admin?) ? ADMIN_LEVEL : nil
  end

  #########################
  # Backend methods

  def same_record_conditions
    { record_type: record_type, record_id: record_id }
  end

  ##
  # Alternate b/w sender_user_id and recipient_user_id
  def same_record_conditions_from_the_other_user
    same_record_conditions.merge( sender_user_id: recipient_user_id )
  end

  def previous_of_same_record
    if record_type.present? && record_id
      self.class.find_by(same_record_conditions)
    else
      nil
    end
  end

  def previous_of_same_record_from_the_other_user
    if record_type.present? && record_id
      self.class.find_by( same_record_conditions_from_the_other_user )
    else
      nil
    end
  end

  ##
  # Same record, answering the other side if self must respond; else if self posting more
  def check_enough_response_to_previous_messages?
    prev_msgs = User::Message.where(same_record_conditions).not_viewed
    respond_enough = true
    prev_msgs.each do|prev_msg|
      if prev_msg.recipient_must_respond? && prev_msg.must_respond_with_class && !is_a?(prev_msg.must_respond_with_class)
        respond_enough = false
      end
    end
    respond_enough
  end

  def mark_viewed_to_previous_of_same_record!(check_previous_message = true)
    if check_enough_response_to_previous_messages?
      User::Message.where(same_record_conditions).where('id != ? and last_viewed_at IS NULL', id).update_all(last_viewed_at: created_at)
    end
  end

  def archive_previous_of_same_record!
    User::Message.where(same_record_conditions).where('id != ? and deleted_at IS NULL', id).update_all(deleted_at: created_at)
  end

  ##
  # Check if admin to seller message.
  def schedule_to_send_email
    if sender.admin?
      send_email
    end
  end

  MESSAGE_DJ_QUEUE = 'message'

  def send_email
    User::MessageMailer.new_message(self).deliver
  end

  handle_asynchronously :send_email, priority: 2, queue: MESSAGE_DJ_QUEUE if Rails.env.production?

  protected

  def set_defaults
    self.group_name = self.class.group_name
    self.level = overriding_level || self.class.level
    self.comment = comment&.strip&.compact
  end

  def evaludate_inline(source)
    s = source.clone
    source.scan(INLINE_CODE_IN_STRING){|code_match| s.gsub!(code_match[0], eval(code_match[1]).to_s ) }.class
    s
  end
end
