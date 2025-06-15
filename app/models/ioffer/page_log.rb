class Ioffer::PageLog < ApplicationRecord

  # @request [ActionDispatch::Request]
  def self.record_request(request)
    log = PageLog.find_or_initialize_by(ip: request.ip, url_path: request.original_fullpath) do|r|
      r.url_params = request.query_parameters
    end
    log.last_request_at = Time.now
    log.requests_count = log.requests_count.to_i + 1
    log.save
  end
end