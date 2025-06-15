module Filter
  class Domain
    DOMAINS_OF_CHINA_REGEXP = /\b(163|126|10086|qq|189|aliyun|foxmail|sohu|sina|21cn|tom)\.[a-z]{2,4}(\.[a-z]{2,3})?$/i

    ##
    # @return [String] country name in lowercase
    def self.convert_domain_to_country(domain_or_email)
      domain = domain_or_email.index('@') ? domain_or_email.split('@').last : domain_or_email
      if DOMAINS_OF_CHINA_REGEXP =~ domain
        'china'
      else
        nil
      end
    end

    def self.domain_from_china?(domain_or_email)
      convert_domain_to_country(domain_or_email) == 'china'
    end
  end
end