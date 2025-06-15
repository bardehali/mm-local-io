module MaxMind::GeoIP2::Model::AsnDecorator
  DB_FILE_PATH = File.join( Rails.root, 'data/GeoLite/GeoLite2-ASN.mmdb') unless defined?(DB_FILE_PATH)

  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def reader(file_path = nil)
      @@reader ||= MaxMind::GeoIP2::Reader.new( file_path || DB_FILE_PATH )
    end
  end
end

MaxMind::GeoIP2::Model::ASN.prepend(MaxMind::GeoIP2::Model::AsnDecorator) if MaxMind::GeoIP2::Model::ASN.included_modules.exclude?(MaxMind::GeoIP2::Model::AsnDecorator)
