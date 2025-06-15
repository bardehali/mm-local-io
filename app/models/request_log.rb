class RequestLog < ApplicationRecord
  include CommonLog


  scope :on_reset_password, -> { where(group_name: 'show_reset_password') }
  scope :on_sign_in, -> { where(group_name: 'sign_in') }

  after_create :update_user_attributes

  def self.save_request(request, other_attributes = {})
    create(other_attributes.merge(
      method: request.method,
      full_url: request.fullpath,
      url_path: request.path,
      url_params: request.query_parameters,
      referer_url: request.referer,
      ip: request.remote_ip
    ))
  end


  protected

  ##
  # 
  def update_user_attributes(user = nil)
    user ||= self.user
    return if user.nil?
    
    a = user.attributes.slice('country', 'country_code', 'zipcode', 'timezone')
    a['country'] = country # if a['country'].blank?
    a['country_code'] = country_code # if a['country_code'].blank?
    a['zipcode'] = zip_code # if a['zipcode'].blank?
    a['timezone'] = time_zone # if a['timezone'].blank?
    user.update_attributes(a)
  end
end