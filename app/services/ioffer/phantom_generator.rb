module Ioffer
  class PhantomGenerator < BaseGenerator
    def assign_inactive_legacy_as_phantom
      phantom_seller_role = Spree::Role.find_or_create_by(name: 'phantom_seller') {|r| r.level = 0; }
      total = 0
      query = Spree::User.eligible_for_phantom_users
      puts "query: #{query.to_sql}"
      puts "Iterate over #{query.count} phantom users"

      query.includes(:ioffer_user, :role_users, :store).order('GMS ASC').limit(5000).each do|user|
        if user.test_or_fake_user?
          next
        end

        puts user.to_s + " w/ roles #{user.spree_roles.collect(&:name) }"

        Spree::User::PhantomGenerator.convert_user_to_phantom_seller(user, phantom_seller_role)
        total += 1
      end
      # Gotta pick some fake users
      if total == 0 && (Rails.env.test? || Rails.env.development?)
        puts 'Make up empty phantom_sellers ----------------------'
        Spree::User::PhantomGenerator.generate_phantom_sellers
      end
      puts '#' * 60
      puts "Total users assigned: #{total}"
  
    end
  end
end