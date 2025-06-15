Rails.application.routes.draw do
  # This line mounts Spree's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to
  # Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the
  # :at option to something different.
  #
  # We ask that you don't use the :as option here, as Spree relies on it being
  # the default of "spree".
  mount Spree::Core::Engine, at: '/'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  Spree::Core::Engine.add_routes do
    ##
    # Admins

    namespace :admin, path: Spree.admin_path do

      match 'dashboard', to: 'base#dashboard', as: :dashboard, via: [:get]
      match 'stats', to: 'base#stats', as: :stats, via: [:get]
      match 'sellers', to: 'users#sellers', as: :sellers, via: [:get]
      match 'all_sellers', to: 'users#all_sellers', as: :all_sellers, via: [:get]
      match 'buyers', to: 'users#buyers', as: :buyers, via: [:get]
      match 'critical_response', to: 'stores#critical_response', as: :critical_response, via: [:get, :put, :post]
      match 'update_options', to: 'stores#update_options', as: :update_options, via: [:put, :post]
      match 'soft_delete_user/:id', to: 'users#soft_delete', as: :soft_delete_user, via: [:put, :post]
      match 'restore/:id', to: 'users#restore', as: :restore_user, via: [:put, :post]
      match 'limit_user/:id', to: 'users#limit_user', as: :limit_user, via: [:put, :post]
      match 'remove_limit/:id', to: 'users#remove_limit', as: :remove_limit, via: [:put, :post]
      match 'niir/:version', to: 'record_reviews#products', as: :niir_version, via: [:get]
      match 'niir', to: 'record_reviews#products', as: :niir, via: [:get]
      match 'record_reviews/mark_reviewed', to: 'record_reviews#mark_reviewed', as: 'mark_record_reviewed', via: [:get, :put]

      match 'remove_user_list_user/:id', to: 'user_lists#remove_user', as: 'remove_user_list_user', via: [:put, :post, :delete]
      match 'remove_product_list_product/:id', to: 'product_lists#remove_product', as: 'remove_product_list_product', via: [:put, :post, :delete]
      resources :user_lists
      resources :record_reviews
      resources :product_lists

      # Product manager
      match '/product_manager/preview_takedown' => 'product_manager#preview_takedown', as: 'preview_takedown', via: [:put, :post, :delete]
      match '/product_manager/takedown' => 'product_manager#takedown', as: 'takedown', via: [:put, :post, :delete]
      get '/product_manager' => 'product_manager#index', as: 'product_manager'

      # Products
      match '/wanted_products', to: 'stores#find_and_list_items', as: 'wanted_products', via: [:get]
      match '/listing_policy', to: 'stores#update_listing_policy', as: 'update_item_listing_policy', via: [:put, :post]
      match '/listing_policy', to: 'stores#listing_policy', as: 'item_listing_policy', via: [:get]
      match '/find_and_list_items', to: 'stores#find_and_list_items', as: 'find_and_list_items', via: [:get]
      match '/products/:id/list_same_item' => 'products#list_same_item', as: 'list_same_item', via: [:get]
      match '/products/:id/list_variants' => 'products#list_variants', as: 'list_variants', via: [:put, :post]

      match 'other_listings', to: 'products#adopted', as: 'other_listings', via: [:get]
      match 'products_adopted', to: 'products#adopted', as: 'products_adopted', via: [:get]
      match '/products/top_selling', to: 'products#top_selling', as: 'products_top_selling', via: [:get]
      match 'products/toggle_selling_taxon', to: 'products#toggle_selling_taxon', as: 'toggle_selling_taxon', via: [:get, :put, :post]
      match 'products/:id/erase', to: 'products#erase', as: 'erase_product', via: [:delete]
      match '/products/:id/debug' => 'products#show_debug', as: 'product_debug', via: [:get, :put, :post]

      match 'products/:product_id/images/:id/mark_as_main', to: 'images#mark_as_main', as: 'mark_image_as_main', via: [:get, :put, :post]
      match 'products/:product_id/upload_images/:id', to: 'images#delete_image', as: 'product_delete_image', via: [:delete]
      match 'products/:product_id/upload_images', to: 'images#upload_images', as: 'product_upload_images', via: [:put, :post]
      match 'products_batch_update' => 'products#batch_update', as: 'batch_update_products', via: [:put, :post]


      ##
      # Seller
      match '/orders/:id/preview_invoice_email' => 'orders#preview_invoice_email', as:'order_preview_invoice_email', via: [:get]

      # Orders
      match '/orders/:id/update_messages' => 'orders#update_messages', via: [:put, :post], as: 'order_update_messages'
      match '/orders/:id' => 'orders#show', as:'order', via:[:get]
      match '/sales/:state' => 'orders#sales', as:'sales_in_state', via: [:get]
      match '/sales' => 'orders#sales', as:'sales', via: [:get]
      match '/msales' => 'orders#mobile_sales', as:'mobile_sales', via: [:get]

      # Store
      match '/payment_methods_and_retail_stores' => 'store_payment_methods#save_payment_methods_and_retail_stores', as:'payment_methods_and_retail_stores', via: [:get, :put, :post]
      match '/store_payment_methods/toggle' => 'store_payment_methods#toggle', as: 'toggle_store_payment_method', via: [:get, :put, :post]
      resources :store_payment_methods, only:[:index, :show, :update]
      get '/fill_your_shop' => 'stores#fill_your_shop', as: 'fill_your_shop'

      # Imports
      match '/scraper_page_imports/select(.:format)' => 'scraper_page_imports#select', as: 'select_scraper_page_imports', via: [:post, :put]
      match '/products/imported' => 'scraper_page_imports#products', as: 'imported_products', via: [:get]
      match 'scraper_page_imports' => 'scraper_page_imports#products', as: 'page_product_imports', via: [:get]

    end


    # Users
    get Spree.admin_path => 'admin/base#home', as: :admin_default

    get '/account' => 'users#account', as: 'account'
    match '/onboarding/:passcode/password' => 'users#onboarding_change_password', as: 'onboarding_change_password', via: [:get, :put, :post, :patch]
    get '/onboarding/:passcode' => 'users#onboarding', as: 'user_onboarding'

    get '/users/info' => 'admin/users#show', as: 'users_info'
    get '/users/:username' => 'home#not_found', as: 'users_detail'

    devise_scope :spree_user do
      match '/admin/sign_in_as/:id' => 'user_sessions#sign_in_as', as:'admin_sign_in_as', via: [:get, :put, :post]
    end

    ##
    # Products
    match '/products_s' => 'products#index', as: 's_products', via: [:get, :put, :post]
    match '/products_m' => 'products#index', as: 'm_products', via: [:get, :put, :post]
    match '/products_sd' => 'products#index', as: 'sd_products', via: [:get, :put, :post]
    match '/products_md' => 'products#index', as: 'md_products', via: [:get, :put, :post]
    match '/products_l' => 'products#index', as: 'l_products', via: [:get]
    match '/products_c' => 'products#index', as: 'c_products', via: [:get]
    match '/products/:id/exists_in_search' => 'products#exists_in_search', as: 'product_exists_in_search', via: [:get, :put, :post]
    match '/products/:id/related' => 'products#related_products', as: 'related_products', via: [:get, :put, :post]
    match '/related_option_types/:record_type/:record_id' => 'api/option_types#related', as: :related_option_types, via: [:get, :put, :post]
    match '/variants/:id/data' => 'products#variant_data', as: 'product_variant_data', via: [:get, :put, :post]
    match '/option_types/load' => 'api/option_types#load', as: :load_option_types, via: [:get, :put, :post]
    match '/admin/taxons/:id/related_option_types', to: 'admin/taxons#related_option_types', as: :taxon_related_option_types, via: [:get]

    #get '/search', to: 'products#index', as: 'search_by_id'
    #get '/search', to: 'searches#show', as: 'search_by_id'

    ##
    # Buyer
    match '/add_item_to_cart' => 'api/v2/storefront/cart#add_item', via: [:put, :post], as: 'populate_orders'
    match '/select_variant' => 'api/v2/storefront/cart#select_variant', via: [:put, :post], as: 'select_variant'
    match '/orders/:id/help' => 'orders#help', via: [:get], as: 'order_help'
    match '/orders/:id/upload_image' => 'orders#upload_image', via: [:patch, :put, :post], as: 'order_upload_image'
    match '/orders/:id/messages/:message_id' => 'orders#show_message', via: [:get], as: 'order_show_message'
    match '/orders/:id/messages' => 'orders#create_message', via: [:get, :put, :post], as: 'order_create_message'
    match '/orders' => 'orders#index', via: [:get], as: 'orders'
    patch "/orders/:id/update_channel", to: "orders#update_channel", as: :update_order_channel


    # Sellers
    get '/payment_methods_provided' => 'store_payment_methods#payment_methods_provided', as: 'payment_methods_provided'
    get '/payment_method_accounts' => 'store_payment_methods#accounts', as: 'payment_method_accounts'

    ##
    # Orders
    get '/recent_sales(.:format)' => 'orders#recent_sales',  as: 'recent_sales'

    # iOffer Landing
    match '/other' => 'home#other_site_accounts', via: [:get], as:'other'
    match '/contact_info' => 'home#payment_info', via: [:get], as: 'contact_info'
    match '/seller_contact_info' => 'home#payment_info', via: [:get], as: 'seller_contact_info'
    match '/payment_options' => 'home#payment_options', via: [:get], as: 'payment_options'
    match '/seller_obligations' => 'home#seller_obligations', via: [:get], as: 'seller_obligations'

    # iOffer Static Pages
    match '/privacy_policy' => 'base#privacy_policy', via: [:get], as:'privacy'
    match '/terms' => 'base#terms_of_use', via: [:get], as:'terms'

    get '/u/:code', to: 'item_reviews#show', as: :item_review
    get '/u/:code/purchases', to: 'item_reviews#purchases', as: :purchases_item_review


    # Must be here for spree home to access path urls
    namespace :ioffer, path: '/' do

      match '/seller_signup' => '/ioffer/users#new', via: [:get], as:'seller_signup'
      match '/payments' => '/ioffer/payment_methods#index', via: [:get], as: 'payments'
      match '/select_payment_methods' => '/ioffer/payment_methods#select_payment_methods', via: [:post, :put, :patch], as:'select_payment_methods'

      match '/save_contact_info' => '/ioffer/payment_methods#save_payment_info', via:[:put, :post], as: 'save_contact_info'

      match '/categories_brands' => '/ioffer/brands#index', via: [:get], as:'brands'
      match '/what_categories' => '/ioffer/brands#index', via: [:get], as:'what_categories'
      match '/select_brands' => '/ioffer/brands#select_brands', via: [:post, :put, :patch], as:'select_brands'
      match '/select_categories' => '/ioffer/categories#select_categories', via: [:post, :put, :patch], as:'select_categories'

      match '/email_subscriptions' => '/ioffer/email_subscriptions#create', via: [:post], as: 'email_subscriptions'
      match '/other_site_accounts' => '/ioffer/other_site_accounts#create', via: [:post]
    end
  end # add_routes

  ##
  # Messages

  namespace :user, path: '/' do
    match 'messages/list' => 'messages#index', via: [:get], as:'messages_list'
    resources :messages
    match 'messages/:id/image/:filename' => 'messages#image', via: [:get], as:'message_image'
    match 'messages/:id/thumb/:filename' => 'messages#thumb', via: [:get], as:'message_thumb'
  end

  ##
  # Search
  resources :search_keywords, only:[:index]

  # Retail
  namespace :retail, path: 'admin/retail' do
    resources :sites
    resources :site_categories, only: [:update, :show, :index]
  end

  # Scraper
  namespace :scraper, path:'admin/scraper' do
    match 'pages/preview(.:format)' => 'pages#preview', as: 'page_preview', via: [:get, :post, :put]
    match 'pages/:id/fetch(.:format)' => 'pages#fetch', as: 'page_fetch', via: [:get, :post, :put]
    match 'pages/:id/show_product(.:format)' => 'pages#show_product_from_saved_page', as:
    'page_show_product', via: [:get, :post, :put]
    match 'pages/:id/source_file(.:format)' => 'pages#source_file', as: 'page_source_file', via: [:get, :post, :put]

    resources :pages
  end

  # iOffer

  namespace :ioffer, path: '/' do
    get '/ioffer/logout' => 'users#logout', as: 'logout'
    resources :users, except: [:destroy]

    get '/seller_onboarding' => 'users#seller_onboarding', as: 'seller_onboarding'
    get '/getting_started' => 'users#getting_started', as: 'seller_getting_started'
    get '/next_after_save' => 'users#next_after_save', as: 'next_after_save'
  end

  # Customized admins outside of Spree
  namespace :admin, path: '/admin' do
    get '/servers/:server_hostname/restart_process' => 'servers#restart_process', as: 'server_restart_process'
    get '/servers' => 'servers#index', as: 'servers'

  end

  # Root URLs
  get '/home' => 'spree/home#index', as: 'home'
  get '/p/:id' => 'spree/products#show', as: 'show_p'
  get '/v/:variant_id' => 'spree/products#show_by_variant', as: 'show_product_by_variant'
  get '/vp/:variant_adoption_id' => 'spree/products#show_by_variant_adoption', as: 'show_product_by_variant_adoption'
  get '/nvp/:variant_adoption_id' => 'spree/products#show_by_variant_adoption', as: 'show_admin_product_by_variant_adoption'

  # Fake pages or forward to spree
  match '/si/:keywords' => 'spree/products#index', via: [:get], as:'ioffer_si_query'
  match '/search/items/:keywords' => 'spree/products#index', via: [:get], as:'ioffer_items_search_query'
  match '/search/items' => 'spree/products#index', via: [:get], as:'ioffer_items_search'
  match '/selling/:store_id' => 'spree/home#not_found', via: [:get], as:'ioffer_selling_store'
  match '/i/:item_id' => 'spree/products#show_item_with_search_results', via: [:get], as:'ioffer_item_detail'
  match '/i' => 'spree/products#index', via: [:get], as:'ioffer_item_index'
  match '/c/:category_id/:keywords' => 'spree/products#index', via: [:get], as:'ioffer_categories_search'
  match '/c/:category_id' => 'spree/products#index', via: [:get], as:'ioffer_categories_detail'
  match '/c' => 'spree/products#index', via: [:get], as:'ioffer_categories_index'
  match '/ratings/:user_id' => 'spree/home#not_found', via: [:get], as:'ioffer_user_ratings'
  match '/offer_transactions/:whatever/:id' => 'spree/home#not_found', via: [:get, :put, :post], as:'ioffer_offer_txns_action'
  match '/offers/:whatever' => 'spree/home#not_found', via: [:get, :put, :post], as:'ioffer_offer_action'

  get '/shares/:code', to: 'spree/logs#share_click'
  get '/shared/:code', to: 'spree/logs#share_click'

end
