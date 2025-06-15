class UserReport::EmailDelivery < ::UserReport
  def self.report_delivery_error(record, exception, recipient_user_id = nil)
    create(
      record_type: record.class.to_s, record_id: record.id, 
      reporter_user_id: Spree::User.fetch_admin.id,
      reported_user_id: recipient_user_id,
      comment: "#{exception.message}\n   #{exception.backtrace.join("\n  ") }"
    )
  end
end