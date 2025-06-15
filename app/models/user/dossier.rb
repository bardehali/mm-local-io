##
#
module User
  class Dossier
    
    attr_accessor :user_id

    def initialize(user_id)
      self.user_id = user_id
    end

    ##
    # All the sellers that have posted products
    def self.populate_all_sellers!
      Spree::User.joins("inner join #{Spree::Product.table_name} on #{Spree::Product.table_name}.user_id=#{Spree::User.table_name}.id").
      distinct('spree_users.id').in_batches do|subq|
        subq.each do|u|
          ::User::Dossier.new(u.id).populate!
        end
      end.class
    end

    ##
    # @return [Array of Spree::UserSellingOptionValue joined w/ Array Spree::UserSellingTaxon]
    def populate!
      ::Spree::UserSellingOptionValue.populate_for(user_id) + 
        ::Spree::UserSellingTaxon.populate_for(user_id)
    end
  end
end