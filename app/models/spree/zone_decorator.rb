module Spree::ZoneDecorator
  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def default_checkout_zone
      find_by(name: Spree::Config[:checkout_zone])
    end

    ##
    # Somehow these zones or their zone members got lost.  This would break shipping method
    # functions.
    def populate_zones
      {"EU_VAT"=>["Poland", "Finland", "Portugal", "Romania", "Germany", "France", "Slovakia", "Hungary", "Slovenia", "Ireland", "Austria", "Spain", "Italy", "Belgium", "Sweden", "Latvia", "Bulgaria", "United Kingdom", "Lithuania", "Cyprus", "Luxembourg", "Malta", "Denmark", "Netherlands", "Estonia", "Croatia", "Czechia", "Greece"], "North America"=>["Canada", "United States"], "South America"=>["Argentina", "Bolivia, Plurinational State of", "Brazil", "Chile", "Colombia", "Ecuador", "Falkland Islands (Malvinas)", "French Guiana", "Guyana", "Paraguay", "Peru", "Suriname", "Uruguay", "Venezuela, Bolivarian Republic of"], "Middle East"=>["Bahrain", "Cyprus", "Egypt", "Iran, Islamic Republic of", "Iraq", "Israel", "Jordan", "Kuwait", "Lebanon", "Oman", "Qatar", "Saudi Arabia", "Syrian Arab Republic", "Turkey", "United Arab Emirates", "Yemen"], "Asia"=>["Afghanistan", "Armenia", "Azerbaijan", "Bahrain", "Bangladesh", "Bhutan", "Brunei Darussalam", "Cambodia", "China", "Christmas Island", "Cocos (Keeling) Islands", "British Indian Ocean Territory", "Georgia", "Hong Kong", "India", "Indonesia", "Iran, Islamic Republic of", "Iraq", "Israel", "Japan", "Jordan", "Kazakhstan", "Kuwait", "Kyrgyzstan", "Lao People's Democratic Republic", "Lebanon", "Macao", "Malaysia", "Maldives", "Mongolia", "Myanmar", "Nepal", "Korea, Democratic People's Republic of", "Oman", "Pakistan", "Palestine, State of", "Philippines", "Qatar", "Saudi Arabia", "Singapore", "Korea, Republic of", "Sri Lanka", "Syrian Arab Republic", "Taiwan", "Tajikistan", "Thailand", "Turkey", "Turkmenistan", "United Arab Emirates", "Uzbekistan", "Vietnam", "Yemen"]}.each_pair do|zone_name, country_names|

        zone = Spree::Zone.find_or_create_by(name: zone_name) do|z|
          z.description = zone_name
          z.default_tax = true
          z.kind = 'country'
        end
        country_names.each do|cname|
          country = Spree::Country.find_by(name: cname)
          next if country.nil? # happens if DB is not in sync
          puts "  #{country&.id} - #{country&.name}"
          zone.zone_members.find_or_create_by(zoneable_type:'Spree::Country', zoneable_id: country.id)
        end
      end
    end
  end
end

Spree::Zone.prepend(Spree::ZoneDecorator) if Spree::Zone.included_modules.exclude?(Spree::ZoneDecorator)
