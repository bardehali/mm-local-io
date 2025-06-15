module Spree::AddressDecorator

  def self.prepended(base)
    base.extend ClassMethods

    base.attr_accessor :longitude, :latitude

    base.geocoded_by :full_address
    base.after_validation :geocode

    # Remove zipcode validation
    base._validators.reject! { |key, _| key == :zipcode }
    base._validate_callbacks.each do |callback|
      if callback.raw_filter.respond_to?(:attributes) && callback.raw_filter.attributes.include?(:zipcode)
        callback.raw_filter.attributes.delete(:zipcode)
      end
    end

    base.validate :clear_zipcode_errors

  end

  def clear_zipcode_errors
    errors.delete(:zipcode)
  end


  module ClassMethods

    ##
    # Extra checking of phone requirement.  Just cannot override super class methods.
    def required_fields
      list = super
      Spree::Config[:address_requires_phone] ? list : list.reject{|f| f == :phone }
    end

    ##
    #
    def parse(address_s)

    end
  end

  def full_address(delimeter = ', ', part_delimeter = '')
    [address1, part_delimeter, address2, part_delimeter, "#{city}, #{state_text} #{zipcode}", part_delimeter,
      country.to_s
    ].reject(&:blank?).map { |attribute| ERB::Util.html_escape(attribute) }.join(delimeter)
  end

  # Without city, zip
  def short_address(delimeter = ', ', part_delimeter = '')
    [address1, part_delimeter, "#{state_text}, #{country&.iso}"
    ].reject(&:blank?).map { |attribute| ERB::Util.html_escape(attribute) }.join(delimeter)
  end
end

Spree::Address.prepend(Spree::AddressDecorator) if Spree::Address.included_modules.exclude?(Spree::AddressDecorator)
