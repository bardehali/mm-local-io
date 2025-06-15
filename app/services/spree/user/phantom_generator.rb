module Spree::User::PhantomGenerator
  
  #######################
  # Class Methods
  
  ##
  # @query [ActiveRecord::Relation or Collection] default is limited (15 to 25) 
  #   
  def self.generate_phantom_sellers(query = nil, dry_run = false)
    query ||= Spree::User.joins(:role_users).where(
      Spree::RoleUser.table_name => { role_id: [::Spree::Role.fake_user_role&.id] } ).
      limit(15 + rand(10) ).order("RAND() ASC")
      
    query.each do|user|
      convert_user_to_phantom_seller(user, phantom_seller_role) unless dry_run
    end
  end

  def self.convert_user_to_phantom_seller(user, phantom_seller_role = nil)
    phantom_seller_role ||= Spree::Role.phantom_seller_role
    user.role_users.delete_all
    user.role_users.create(role_id: phantom_seller_role.id)
    if (paypal = Spree::PaymentMethod.paypal) && user.store
      Spree::StorePaymentMethod.where(payment_method_id: paypal.id, store_id: user.store.id).delete_all
    end
    user.calculate_seller_rank!
  end

end
