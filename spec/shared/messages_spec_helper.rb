module MessagesSpecHelper
  def check_message_for(record, expected_sender_id, expected_recipient_id, &block)
    msg = User::Message.find_by(record_type: record.class.to_s, record_id: record.id)
    expect(msg).not_to be_nil
    yield msg if block_given?
    expect(msg.group_name).to eq(User::NewOrder.group_name)

    expect(msg.sender_user_id).to eq(expected_sender_id)
    expect(msg.recipient_user_id).to eq(expected_recipient_id)
  end
end