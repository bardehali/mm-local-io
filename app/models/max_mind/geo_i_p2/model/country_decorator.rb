module MaxMind::GeoIP2::Model::CountryDecorator
  DB_FILE_PATH = File.join( Rails.root, 'data/GeoLite/GeoLite2-Country.mmdb') unless defined?(DB_FILE_PATH)

  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def reader(file_path = nil)
      @@reader ||= MaxMind::GeoIP2::Reader.new( file_path || DB_FILE_PATH )
    end
  end
end

MaxMind::GeoIP2::Model::Country.prepend(MaxMind::GeoIP2::Model::CountryDecorator) if MaxMind::GeoIP2::Model::Country.included_modules.exclude?(MaxMind::GeoIP2::Model::CountryDecorator)
