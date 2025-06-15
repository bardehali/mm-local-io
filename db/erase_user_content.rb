class EraseUserContent < ActiveRecord::Migration[6.0]
  
  def change
    # When importing some INSERT statements from another DB, primary keys might 
    # have duplicate value conflict.  Since these are sample data, so better 
    # just erase them.

    # Spree::Product.connection.execute('DELETE FROM friendly_id_slugs')
    # Spree::Payment.all.each(&:destroy)
    # Spree::CreditCard.delete_all

    # Spree::RefundReason.delete_all
    # Spree::Order.all.each(&:destroy)

    # #Spree::ShippingCategory.all.each(&:destroy)
    # #Spree::ShippingMethodCategory.all.each(&:destroy)
    # #Spree::ShippingMethod.delete_all

    # Spree::TaxCategory.delete_all

    # # Tables to be replaced
    # Spree::Property.all.each(&:destroy)
    # Spree::Product.all.each do|prod|
    #   prod.really_destroy!
    # end
    # Spree::OptionValue.all.each(&:destroy)
    # Spree::OptionType.all.each(&:destroy)
    # Spree::Asset.all.each(&:destroy)

    # Spree::User.delete_all # somehow frozen Hash crashed really_destroy!
    # Spree::Product.connection.execute('DELETE FROM spree_role_users')
    # Spree::Role.all.each(&:destroy)

    # Spree::Store.delete_all


    # Spree::Taxonomy.delete_all
    # Spree::Taxon.delete_all

  end
end
