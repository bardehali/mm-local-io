##
# Creates Spree::User based on given email after modifying 
# username segment and ensures the targeted email does not 
# exist in database.
module Ioffer
  class UserGenerator < BaseGenerator
    include ActiveRecord::CallbackModifier

    require 'random_picker'

    attr_accessor :settings

    SETTING_DEFAULTS = {
      dry_run: false,
      user_list: 'generated_users',
      availability_tries: 50,
      default_password: "D$C4hM9q<'T2)Zd'(V"
    }
    CHARACTERS_TO_APPEND = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9).freeze
    COUNTRY_DISTRIBUTION_PERCENTAGES = {
      'united states' => 35,
      'united kingdom' => 17,
      'france' => 12,
      'italy' => 5,
      'spain' => 4,
      'canada' => 3,
      'germany' => 3,
      'saudi arabia' => 2,
      'australia' => 2,
      'netherlands' => 2,
      nil => 15
    }.freeze


    ##
    # singular
    # @return [Spree::User or nil]
    def generate_from_email(email, user_attributes = {})
      found_email = find_available_email(email)
      user = nil
      if found_email
        password = user_attributes[:password] || settings[:default_password]
        h = user_attributes.merge(email: found_email, 
          username: normalize_username(found_email.split('@').first), password: password )

        user = Spree::User.new(h)
        user.password = password
        d = ( (7 * 24 * 60) + rand(128 * 24 * 60) ).minutes.ago
        user.created_at = d, 
        user.confirmed_at = d
        user.confirmation_token = 'VBNECAPXQOFRX'
        user.role_users = [ Spree::RoleUser.new(role_id: Spree::Role.fake_user_role&.id) ]
        user.skip_calculate_stats = true

        unless settings[:dry_run] == true
          without_create_and_update_callbacks(user) do
            if user.save
              Spree::UserListUser.find_or_create_by(user_list_id: user_list.id, user_id: user.id)
              user.skip_confirmation_notification! if user.respond_to?(:skip_confirmation_notification!)
            end
          end
        end
      end
      user
    end

    ##
    # @klass_or_query [Class or ActiveRecord::Relation]
    # @yield [Spree::User just created]
    # @return [Array of Spree::User]
    def batch_run(count, klass_or_query, email_attribute, common_user_attributes = {}, &block)
      # TODO: random disgest of email
    end

    def batch_run_based_on(count, klass_or_query, email_attribute, common_user_attributes = {}, &block)
      total_count = klass_or_query.count
      query = klass_or_query.is_a?(ActiveRecord::Relation) ? klass_or_query : klass_or_query.where(nil)
      users_created = []
      return users_created if count < 1

      logger.debug "UserGenerator.picking #{count} from #{total_count} #{klass_or_query}"
      RandomPicker.pick_indices(count, total_count).each do|index|
        which_record = query.limit(1).offset(index).first
        user = generate_from_email(which_record.send(email_attribute) )
        # puts '    %20s | %40s vs %40s | %5s' % [user.username, which_record.send(email_attribute), user.email, user.valid?.to_s]
        logger.info "      #{user.errors.messages}" if user.errors.size > 0

        if user
          users_created << user
          yield user if block_given?
        end
      end
      users_created
    end

    ##
    # Sets country of these users according to COUNTRY_DISTRIBUTION_PERCENTAGES.
    # Would override existing user.country.
    # @users_query [Spree::User::ActiveRecord_Relation] so can get total count and iterate w/ it.
    def distribute_countries_to(users_query)
      dry_run = settings[:dry_run]
      total_users_count = users_query.count
      other_countries = Spree::Country.where("name NOT IN (?)", COUNTRY_DISTRIBUTION_PERCENTAGES.keys.compact).select('name').collect(&:name)
      ny_state = Spree::State.find_by(name:'new york')

      # $country_name => count targted
      country_counters = {}
      COUNTRY_DISTRIBUTION_PERCENTAGES.each_pair do|k, v|
        country_counters[k] ||= (total_users_count / 100.0 * v).round
      end

      # assign each user w/ rotation
      dist_index = 0
      users_query.to_a.shuffle.each do|user|
        puts "#{user.login} ------------------------------------------"
        country_name = nil
        trial_count = 0
        while (trial_count < country_counters.size) && country_name.blank?
          trial_count += 1
          cur_country = country_counters.keys[dist_index]
          counter = country_counters[cur_country]
          dist_index += 1
          dist_index = 0 if dist_index >= country_counters.size
          
          puts( '%40s | %4d' % [cur_country, counter] ) if counter > 0
          next if counter == 0

          country_name = cur_country
          if country_name.nil? # random
            country_name = other_countries[ rand(other_countries.size - 1) ]
            puts "   RANDOM => #{country_name}"
          end

          if country_name.present?
            counter -= 1
            country_counters[cur_country] = counter
            break
          end
        end

        if country_name.present?
          unless dry_run
            the_country = Spree::Country.find_by(name: country_name)
            user.update(country: country_name.titleize, country_code: the_country.iso)
            address = user.addresses.first
            address.update(country_id: the_country.id) if address
            if address.nil?
              user.addresses.create(firstname: user.firstname || user.display_name || user.login,
                lastname: user.lastname, address1:'10 Market St', city:'New York', zipcode:'14120', 
                state_id: ny_state.id, 
                country_id: the_country.id )
            end
          end
        end
      end
    end

    protected

    def normalize_settings(settings)
      SETTING_DEFAULTS.each_pair do|key, default_value|
        settings[key] = default_value if settings[key].nil?
      end
      settings
    end

    ##
    # @return [String or nil]
    def find_available_email(email, characters_to_append = nil, how_many_tries = 50)
      found_email = nil
      email_parts = email.split('@')
      username_prefix = normalize_username( email_parts[0] )
      email_parts[1].gsub!(/([^a-z0-9\.]+)/i, '') # some times the subscribers type weird characters
      characters_to_append ||= CHARACTERS_TO_APPEND

      1.upto(how_many_tries) do|i|
        suffix = ''
        1.upto(3).each do
          suffix << characters_to_append[ rand(characters_to_append.size - 1) ]
        end
        cur_username = username_prefix + suffix
        existing_count = Spree::User.where('email = ? OR username = ?', cur_username + '@' + email_parts[1], cur_username ).count
        if existing_count == 0
          found_email = cur_username + '@' + email_parts[1]
          break
        end
      end
      found_email
    end

    ACCEPTABLE_FIRST_CHARACTERS_OF_USERNAME = %w(a b c d e f g h i j k l m n o p q r s t u v w x y z)
    def normalize_username(username)
      username.gsub(/^([^a-z])/i, ACCEPTABLE_FIRST_CHARACTERS_OF_USERNAME.sample).gsub(/([^a-z0-9]+)/i, '')[0,60]
    end
  end
end