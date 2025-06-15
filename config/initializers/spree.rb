# Configure Spree Preferences
#
# Note: Initializing preferences available within the Admin will overwrite any changes that were made through the user interface when you restart.
#       If you would like users to be able to update a setting with the Admin it should NOT be set here.
#
# Note: If a preference is set here it will be stored within the cache & database upon initialization.
#       Just removing an entry from this initializer will not make the preference value go away.
#       Instead you must either set a new value or remove entry, clear cache, and remove database entry.
#
# In order to initialize a setting do:
# config.setting_name = 'new value'
Spree.config do |config|

  config.logo = 'logo/iOffer_logo_color.png'

  # Example:
  # Uncomment to stop tracking inventory levels in the application
  config.track_inventory_levels = false

  config.always_put_site_name_in_title = false

  config.require_master_price = true
  #config.show_products_without_price = false

  config.address_requires_phone = false
end

# Configure Spree Dependencies
#
# Note: If a dependency is set here it will NOT be stored within the cache & database upon initialization.
#       Just removing an entry from this initializer will make the dependency value go away.
#
Spree.dependencies do |dependencies|
  # Example:
  # Uncomment to change the default Service handling adding Items to Cart
  # dependencies.cart_add_item_service = 'MyNewAwesomeService'
end


Spree.config do |config|
  config.admin_path = '/admin'
end


Spree.user_class = 'Spree::LegacyUser'
Spree::Auth::Config[:confirmable] = true

Spree::PermittedAttributes.class_variable_set('@@user_attributes', [:email, :username, :display_name, :login, :password, :password_confirmation] )
Spree::PermittedAttributes.class_variable_get('@@product_attributes') << :uploaded_images
Spree::PermittedAttributes.class_variable_get('@@product_attributes') << :variant_price
Spree::PermittedAttributes.class_variable_set('@@image_attributes',
  Spree::PermittedAttributes.class_variable_get('@@image_attributes') + [:attachment_content_type, :attachment_file_name, :old_filepath, :filename]
)
Spree::PermittedAttributes.class_variable_set('@@taxon_attributes', Spree::PermittedAttributes.class_variable_get('@@taxon_attributes') + [:option_type_ids, :searchable_option_type_ids] )
