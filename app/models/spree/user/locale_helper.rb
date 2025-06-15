module Spree::User::LocaleHelper
  extend ActiveSupport::Concern

  included do
    after_create :generate_address!
  end

  ##
  # Based on GeoIp with saved current_sign_in_ip.
  def generate_address!
    if !@current_sign_in_ip_updated && acceptable_ip?(current_sign_in_ip) && acceptable_ip?(current_sign_in_ip_was)
      @current_sign_in_ip_updated = true # prevent looping after calls
      h = GeoIp.geolocation(current_sign_in_ip, :timezone => true)
      self.update_attributes(country: h[:country_name], country_code: h[:country_code],
        zipcode: h[:zip_code], timezone: h[:timezone] ) if h.size > 0
    else
      nil
    end
  rescue Timeout::Error, JSON::ParserError
    ::Spree::User.logger.warn 'Problem with request to GeoIp API'
  rescue ArgumentError => e
    ::Spree::User.logger.warn "Problem in fetching location of #{current_sign_in_ip}: #{e}"
  end

  ##
  # Using ipinfodb.com to fetch basic location based on IP.
  # @return [Hash w/ keys :ip, :country_code, :country_name, :state, :city, :zip, :latitude, :longitude, :time_zone]
  def fetch_ip_info(ip_to_fetch)
    h = {}
    begin
      # Expected format: "OK;;72.68.110.17;US;United States of America;New Jersey;Newark;07101;40.7357;-74.1724;-05:00"
      if ip_to_fetch == '127.0.0.01'
        h = {ip: ip_to_fetch }
      else
        location_response = Net::HTTP.get('api.ipinfodb.com', '/v3/ip-city.json?key=d691cc3efb502ac2258c6bb7b82f4c61960af20f3d9668ddcc1bd4a75f274d1a&ip=' + ip_to_fetch)
        parts = location_response.split(';')
        part_keys_in_order = [nil, nil, :ip, :country_code, :country_name, :state, :city, :zip, :latitude, :longitude, :timezone].freeze
        parts.each_with_index do|p, i|
          h[ part_keys_in_order[i] ] = p
        end
      end
    rescue Exception => fetch_e
      logger.warn "** Problem fetch_ip_info w/ #{ip_to_fetch}: #{fetch_e}"
      h
    end
  end

  def set_geo_location_data!
    if last_sign_in_ip.present?
      reader = MaxMind::GeoIP2::Model::City.reader
      record = reader.city(last_sign_in_ip)
      self.country = record.country.names['en'] || record.country.name
      self.country_code = record.country.iso_code
      self.zipcode = record.postal.code
      self.timezone = record.location.time_zone
      self.save
    end
  rescue MaxMind::GeoIP2::AddressNotFoundError
  end
end