##
# Commonly shared attributes and functions of RequestLog and SearchLog
module CommonLog
  extend ActiveSupport::Concern

  included do
    # Attributes not in DB schema
    attr_accessor :country_code, :time_zone

    belongs_to :user, class_name:'Spree::User', optional: true

    before_save :set_more_data
  end


  def location_combined(delimiter = ', ')
    list = if country == 'United States'
      [city, state_iso_code, 'US']
    else
      [city, country]
    end
    list.reject(&:blank?).join(delimiter)
  end


  MAX_SIGN_IN_LOGS_TO_KEEP_PER_USER = 10

  ##
  # Might be called outside of before callback.
  # Based on https://github.com/maxmind/GeoIP2-ruby
  # @return [Hash of :city and :country]
  def set_more_data
    if ip.present?
      begin
        reader = MaxMind::GeoIP2::Model::City.reader
        record = reader.city(ip)
        self.country = record.country.names.try(:[], 'en') || record.country.name
        self.country_code = record.country.iso_code
        self.city = record.city&.name
        self.state = record.most_specific_subdivision&.name # Minnesota
        self.state_iso_code = record.most_specific_subdivision&.iso_code # MN
        self.zip_code = record.postal&.code # 55455

        self.latitude = record.location.latitude # 44.9733
        self.longitude = record.location.longitude # -93.2323
        if record.location&.time_zone && record.location.time_zone.match(/\d+/)
          self.time_zone = record.location.time_zone
        else
          begin
            self.time_zone = ('%03d:00' % [ActiveSupport::TimeZone.find_tzinfo(record.location.time_zone).period_for_local( Time.now ).utc_offset / 3600] )
          rescue Exception => time_zone_e
            logger.warn "** Problem parsing time_zone #{record.location.time_zone} IP #{ip}: #{time_zone_e}"
          end
        end

        # --- ASN lookup ---
        asn_reader = MaxMind::GeoIP2::Model::ASN.reader
        asn_record = asn_reader.asn(ip)
        if asn_record&.autonomous_system_number.present?
          self.asn     = asn_record.autonomous_system_number
          self.asn_org = asn_record.autonomous_system_organization
        else
          logger.warn "** ASN lookup returned nothing for IP #{ip}"
        end

      rescue MaxMind::GeoIP2::AddressNotFoundError
        logger.info "** No city for IP #{ip}"
      rescue Exception => read_e
        logger.warn "** Problem fetching city by IP #{ip}: #{read_e}\n#{read_e.backtrace.join("\n")}"
      end
      { country: country, country_code: country_code, city: city, zip_code: zip_code, time_zone: time_zone }
    else
      nil
    end
  end



end
