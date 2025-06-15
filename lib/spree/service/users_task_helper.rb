module Spree
  module Service
    module UsersTaskHelper
      extend ActiveSupport::Concern
      
      USER_ATTRIBUTE_RULES = {
        id: /\Aid\Z/i,
        username: /\A(seller|user|user[_\s]?name)(_?id)?\Z/i,
        email: /email\Z/i,
        rating: /rating(\s+score|ratio)?\Z/i,
        gms: /\Agms\Z/i,
        transactions_count: /\Atransactions?|trx\Z/i,
        items_count: /\Aitems?(\s+count)\Z/i,
        name: /\A(first|last)?\s*name\Z/i,
        location: /\Alocation\Z/i,
        member_since: /\Amember\s+since\Z/i,
        phone: /\Aphone(\s+number)?\Z/i,
        address: /\Aaddress|registration\Z/i,
        positive: /\Apositive(\s+rating)?\Z/i,
        negative: /\Anegative(\s+rating)?\Z/i
      }
      USER_DATE_ATTRIBUTES = [:member_since]
      USER_MONEY_ATTRIBUTES = [:gms]
      USER_PERCENTAGE_ATTRIBUTES = [:rating]
      
      included do
        
        ##
        # The attribute name and header names 
        # @headers_mapping [Hash] one created by make_headers_mapping.
        def make_user_attributes(csv_row_hash, headers_mapping)
          attr = {}
          csv_row_hash.each_pair do|k, v|
            if (attr_name = headers_mapping[k.to_s] )
              if USER_DATE_ATTRIBUTES.include?(attr_name)
                if v.is_a?(String)
                  attr[attr_name] = DateTime.parse(v)
                end
              elsif USER_MONEY_ATTRIBUTES.include?(attr_name)
                if v.is_a?(String) && v.present?
                  attr[attr_name] = v.gsub(/([,$])/, '').to_f
                end
              elsif USER_PERCENTAGE_ATTRIBUTES.include?(attr_name)
                if v.is_a?(String) && v =~ /\A([\d.]+)%\Z/
                  attr[attr_name] = $1.to_f
                end
              end
              attr[attr_name] ||= v
            end
          end
          attr
        end
        
        ##
        # Constructs a map of which header represents which attribute based on given 
        # @mapping_rules.
        # @return [Hash]
        def make_headers_mapping(mapping_rules, headers = [])
          h = {}
          _headers = headers.clone
          mapping_rules.each_pair do|attr_name, attr_rule|
            match = _headers.find do|header|
              attr_rule.is_a?(Regexp) ? attr_rule =~ header : header.downcase == attr_name.to_s
            end
            if match
              h[match.to_s] = attr_name
              _headers.delete(match)
            end
          end
          h
        end
      end

      #
    end
  end
end