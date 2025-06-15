class Spree::HomeController < Spree::StoreController
  require 'json'
  include User::MessagesHelper

  layout 'ioffer_application'

  skip_before_action :verify_authenticity_token
  before_action :check_info, only: [:other_site_accounts]
  before_action :load_store_info, only: [:payment_info, :payment_options, :more_payment_options]

  def index
    params.permit(:username, :email, :reset_password_token, :t)
    @title = "Fashion, Sneakers, Purses, Accessories & More"
    @meta_description = "Discover fashion, sneakers, purses, accessories and more on the ultimate online marketplace. Shop unbeatable deals and enjoy free shipping on countless items. Your go-to destination for style and savings!"

    if current_user && spree_current_user.nil?
      logger.debug "-> to sign in w/ current_user #{current_user}"
      bypass_sign_in(current_user.convert_to_spree_user!)
    end
    logger.debug "| current_user #{current_user}, spree_current_user(#{spree_current_user.try(:id)}) #{spree_current_user}, admin? #{spree_current_user.try(:admin?)}"

    @tiles_data = load_tiles_data

    if spree_current_user && spree_current_user.seller?
      load_user_notifications_from_admin
    end

    render_homepage
  end

  def seller_signup
    @page_title = 'I want to seller on iOffer'
  end

  def other_site_accounts
    @page_title = "#{t('site_name')} - Other Site Account"
    if current_user
      current_user.other_site_accounts.each do|other_account|
        instance_variable_set("@#{other_account.site_name}".to_sym, other_account.account_id)
      end
    end
    render 'home/other'
  end

  ##
  # Wechat account and secondary email
  def payment_info
    @page_title = @title = I18n.t('user.contact_info')
    @wechat = Spree::PaymentMethod.wechat || Spree::PaymentMethod.create(
        name:'wechat', description:'WeChat', active: true, available_to_users: true
      )
    render template: 'home/payment_info'
  end

  ##
  # Selected important payment methods like Paypal only, excluding that on payment_info.
  def payment_options
    @page_title = @title = I18n.t('user.payment_methods.payment_options')
    if params[:store_payment_method]
      @store_payment_method = ::Spree::StorePaymentMethod.new(params[:store_payment_method] )
      @store_payment_method.valid?
    end

    render template: 'home/payment_options'
  end

  def seller_obligations

    if params[:user_stats]
      params[:user_stats].each_pair do|name, value|
        stat = ::User::Stat.find_or_initialize_by(user_id: spree_current_user.id,
          name: name.strip)
        stat.value = value&.strip
        stat.save
      end
    end

    @page_title = @title = I18n.t('user.seller_obligations_title')
    @agree_to_clear_payment_instructions = ::User::Stat.find_or_initialize_by(user_id: spree_current_user&.id, name:'agree_to_clear_payment_instructions')
    @agree_to_provide_tracking_info = ::User::Stat.find_or_initialize_by(user_id: spree_current_user&.id, name:'agree_to_provide_tracking_info')
    @agree_to_post_accurate_prices = ::User::Stat.find_or_initialize_by(user_id: spree_current_user&.id, name:'agree_to_post_accurate_prices')
    @agree_to_post_clear_images_descriptions = ::User::Stat.find_or_initialize_by(user_id: spree_current_user&.id, name:'agree_to_post_clear_images_descriptions')

    @options = [@agree_to_clear_payment_instructions, @agree_to_provide_tracking_info, @agree_to_post_accurate_prices, @agree_to_post_clear_images_descriptions]

    render template: 'home/seller_obligations'

  end

  def not_found
    render layout: false, file: "#{Rails.root}/public/404.html"
  end

  private

  def check_info
    logger.debug "| Signed in user: #{session[:signed_in_user]} > current user #{current_user} vs spree_current_user #{spree_current_user}"

  end

  def load_store_info
    if (store = spree_current_user&.fetch_store)
      @store_payment_methods = store.store_payment_methods.includes(:payment_method).to_a
    else
      @store_payment_methods = []
    end
  end

  def load_tiles_data
    file_path = Rails.root.join('data', 'tiles.json')
    file_contents = safe_read_file(file_path)
    begin
      JSON.parse(file_contents)
    rescue JSON::ParserError => e
      logger.error "Failed to parse tiles.json: #{e.message}"
      default_tiles_data # Assuming you have a method to provide default data
    end
  end

  def safe_read_file(file_path)
    File.read(file_path)
  rescue Errno::ENOENT => e
    logger.error "File not found: #{e.message}"
    {}.to_json # Return empty JSON when the file is missing
  end

  def default_tiles_data
    {
        "tiles": [
            {
                "position": 1,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/cdb03efc-bb56-40fd-0d0c-67771c5ccf00/public",
                "image_title": "Sneakers",
                "tile_name": "Sneakers",
                "tile_url": "/products_s?sid=c8my88&utm_source=home&utm_medium=tile&utm_term=sneakers",
                "show_on_mobile": true
            },
            {
                "position": 2,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/f30f7a96-bebf-4030-beeb-118fc7d7d500/public",
    	          "image_title": "Purses",
                "tile_name": "Purses",
                "tile_url": "/products_s?sid=25a5w8&utm_source=home&utm_medium=tile&utm_term=purses",
                "show_on_mobile": true
            },
            {
                "position": 3,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/110849d0-06e4-4d60-8e0a-3a4a4fe46200/public",
                "image_title": "Watches",
                "tile_name": "Watches",
                "tile_url": "/products_s?sid=swt416&utm_source=home&utm_medium=tile&utm_term=watches",
                "show_on_mobile": true
            },
            {
                "position": 4,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/e8ea6a74-3530-4bc3-09e5-75195bc59600/public",
                "image_title": "T-Shirts",
                "tile_name": "T-Shirts",
                "tile_url": "/products_s?sid=u5d48y&utm_source=home&utm_medium=tile&utm_term=tshirts",
                "show_on_mobile": true
            },
            {
                "position": 5,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/16e1377c-10cf-48df-ef2c-5609d6c52700/public",
                "image_title": "Sunglasses",
                "tile_name": "Sunglasses",
                "tile_url": "/products_s?sid=7225o5&utm_source=home&utm_medium=tile&utm_term=sunglasses",
                "show_on_mobile": true
            },
            {
                "position": 6,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/8bad9e9f-5dcb-42c5-96f0-5d404f53ff00/public",
                "image_title": "Backpacks",
                "tile_name": "Backpacks",
                "tile_url": "/products_s?sid=j9lb08&utm_source=home&utm_medium=tile&utm_term=backpacks",
                "show_on_mobile": true
            },
            {
                "position": 7,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/77decd64-0526-4383-9e97-06e7c784ab00/public",
                "image_title": "Belts",
                "tile_name": "Belts",
                "tile_url": "/products_s?sid=67wf31&utm_source=home&utm_medium=tile&utm_term=belts",
                "show_on_mobile": true
            },
            {
                "position": 8,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/4535d51b-fa99-48de-680c-48b5b4998000/public",
                "image_title": "Wallets",
                "tile_name": "Wallets",
                "tile_url": "/products_s?sid=k2r78t&utm_source=home&utm_medium=tile&utm_term=wallets",
                "show_on_mobile": true
            },
            {
                "position": 9,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/d7af0f7e-3be8-4721-39a3-baf37ef45400/public",
                "image_title": "Hats",
                "tile_name": "Hats",
                "tile_url": "/products_s?sid=a20165&utm_source=home&utm_medium=tile&utm_term=hats",
                "show_on_mobile": true
            },
            {
                "position": 10,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/82cb8d54-cfcb-4514-db10-76201d4e2200/public",
                "image_title": "For Men",
                "tile_name": "For Men",
                "tile_url": "/t/categories/mens-fashion?utm_source=home&utm_medium=tile&utm_term=mens-fashion",
                "show_on_mobile": true
            },
            {
                "position": 11,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/62621057-6ca3-4261-c863-f9f20884c000/public",
    	          "image_title": "Totes",
                "tile_name": "Totes",
                "tile_url": "/products_s?sid=4x192l&utm_source=home&utm_medium=tile&utm_term=totes",
                "show_on_mobile": true
            },
            {
                "position": 12,
                "image_url": "https://imagedelivery.net/PhnzJOsSP4zKYuS1D4e4cQ/1ddeb9f6-21f1-43b4-e021-5ae4882fd500/public",
                "image_title": "Women’s Clothing",
                "tile_name": "Women’s Clothing",
                "tile_url": "/products_s?sid=tq8352&utm_source=home&utm_medium=tile&utm_term=womens-clothing",
                "show_on_mobile": true
            }
        ],
        "trending": [
            {
                "position": 1,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/7ttk7m0ctsr/1ergcrgy6o/u7ml1fc/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
    	          "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=ZXJG2E&utm_source=home&utm_medium=recent&utm_term=182660",
                "show_on_mobile": true
            },
            {
                "position": 2,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/q3gsvajv4s0/jqn4oq4ghr/40ehc51/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=LGZ23I&utm_source=home&utm_medium=recent&utm_term=87824",
                "show_on_mobile": true
            },
            {
                "position": 3,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/jl6osqqrkit/3dhw5d2s2q/578k69u/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=0DG9DB&utm_source=home&utm_medium=recent&utm_term=102595",
                "show_on_mobile": true
            },
            {
                "position": 4,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/3gz45b6dqjg/lc5mhfhnj3/h4trskn/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=QKU0OL&utm_source=home&utm_medium=recent&utm_term=33602",
                "show_on_mobile": true
            },
            {
                "position": 5,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/qp8f5d6zk9o/7ezrpofi8n/9w7fokr/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=LTT8AB&utm_source=home&utm_medium=recent&utm_term=174809",
                "show_on_mobile": true
            },
            {
                "position": 6,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/r4y9i4mkxab/6j5lxmo1dk/vvka0dl/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=AKZB9B&utm_source=home&utm_medium=recent&utm_term=182660",
                "show_on_mobile": true
            },
            {
                "position": 7,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/n4oqvrs88o0/alpopl5os4/7z48ia8/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=FWTNHM&utm_source=home&utm_medium=recent&utm_term=87790",
                "show_on_mobile": true
            },
            {
                "position": 8,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/8xx5dw87wdn/031xs8tnp2/2c2yxof/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=5X77IP&utm_source=home&utm_medium=recent&utm_term=189766",
                "show_on_mobile": true
            },
            {
                "position": 9,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/fv7gdjz6t7d/mqbtwloq96/z04s0rb/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=FQNXCQ&utm_source=home&utm_medium=recent&utm_term=182660",
                "show_on_mobile": true
            },
            {
                "position": 10,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/gf47c2m5por/wypiv0eegx/gxo6n03/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=CMRVRS&utm_source=home&utm_medium=recent&utm_term=29184",
                "show_on_mobile": true
            },
            {
                "position": 11,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/0xyh5gndpex/5y2c9j07cg/skh7a06/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=98AWUV&utm_source=home&utm_medium=recent&utm_term=175559",
                "show_on_mobile": true
            },
            {
                "position": 12,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/j5191f1uf7b/8atzrgwc4e/gpldssy/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=H5QXBX&utm_source=home&utm_medium=recent&utm_term=182729",
                "show_on_mobile": true
            },
            {
                "position": 13,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/hz7d0kyj26p/sr3oftvwbn/hsu50fj/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
    	          "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=JP0BQ2&utm_source=home&utm_medium=recent&utm_term=182257",
                "show_on_mobile": true
            },
            {
                "position": 14,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/a2yq523btrg/o43okhh9z4/xgj4owj/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=SV0ULD&utm_source=home&utm_medium=recent&utm_term=189626",
                "show_on_mobile": true
            },
            {
                "position": 15,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/7p1bzdl9uxh/8hhlmx7u8v/h62lqod/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=P0DRL1&utm_source=home&utm_medium=recent&utm_term=87825",
                "show_on_mobile": true
            },
            {
                "position": 16,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/lwtdjbfoeve/n4ifys159c/bftjghn/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=IMZ6X1&utm_source=home&utm_medium=recent&utm_term=91378",
                "show_on_mobile": true
            },
            {
                "position": 17,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/euu4dqz9ku8/fhih9n95zv/g1mknpb/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=FTOB8A&utm_source=home&utm_medium=recent&utm_term=52994",
                "show_on_mobile": true
            },
            {
                "position": 18,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/qeux1p2yig0/d2atjxyv3e/kzakilj/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=W3GUZ2&utm_source=home&utm_medium=recent&utm_term=171771",
                "show_on_mobile": true
            },
            {
                "position": 19,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/c73z1gviwzp/8p29r09yr7/tycdgmv/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=629GUD&utm_source=home&utm_medium=recent&utm_term=91547",
                "show_on_mobile": true
            },
            {
                "position": 20,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/i1q6pcnod2z/39l8tg7zl3/2dpvea0/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=CKVA8T&utm_source=home&utm_medium=recent&utm_term=87789",
                "show_on_mobile": true
            },
            {
                "position": 21,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/134k0ix82eq/ijepdupy9j/6nlrz3g/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=25CEQ6&utm_source=home&utm_medium=recent&utm_term=174808",
                "show_on_mobile": true
            },
            {
                "position": 22,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/1yrew2xn5kl/kg5fq3q3mw/6kl82ah/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=RASSHJ&utm_source=home&utm_medium=recent&utm_term=90411",
                "show_on_mobile": true
            },
            {
                "position": 23,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/4csacreke45/t8fnq3jl06/u7jqkqn/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=PAOJOC&utm_source=home&utm_medium=recent&utm_term=87798",
                "show_on_mobile": true
            },
            {
                "position": 24,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/fy3v378611h/jo3h8t6cm7/7oqtkwd/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=H4NS3Y&utm_source=home&utm_medium=recent&utm_term=29316",
                "show_on_mobile": true
            },
            {
                "position": 25,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/cbc2t1v4wsf/o10qayc7oz/wmowv27/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
    	          "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=M0XV0P&utm_source=home&utm_medium=recent&utm_term=171797",
                "show_on_mobile": true
            },
            {
                "position": 26,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/h311gweu4da/47nqbvun8v/eblazjx/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=DBV2RR&utm_source=home&utm_medium=recent&utm_term=31510",
                "show_on_mobile": true
            },
            {
                "position": 27,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/4pntsfetmpt/d52x5u80lm/jbjy3z6/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=0NNVP4&utm_source=home&utm_medium=recent&utm_term=29297",
                "show_on_mobile": true
            },
            {
                "position": 28,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/7l6w3n8h9hx/0jbn79tqzb/atsgmnp/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=W25DU7&utm_source=home&utm_medium=recent&utm_term=175501",
                "show_on_mobile": true
            },
            {
                "position": 29,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/j9dugmo2cfc/8ldhwf56ce/lhf6wbg/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=510GNR&utm_source=home&utm_medium=recent&utm_term=182458",
                "show_on_mobile": true
            },
            {
                "position": 30,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/kz49vitbl3m/atu2dosdu6/dfafzkt/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=P43K23&utm_source=home&utm_medium=recent&utm_term=171522",
                "show_on_mobile": true
            },
            {
                "position": 31,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/aagkyn3y66x/imt8x6mfxe/3wkyoho/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=K3IOTX&utm_source=home&utm_medium=recent&utm_term=175172",
                "show_on_mobile": true
            },
            {
                "position": 32,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/ots6b4vr64r/m188dqn40m/kmruugh/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=VR9V14&utm_source=home&utm_medium=recent&utm_term=189944",
                "show_on_mobile": true
            },
            {
                "position": 33,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/8kh27pjagps/ukwq7q3cxt/pf11vc2/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=TR7X5T&utm_source=home&utm_medium=recent&utm_term=175391",
                "show_on_mobile": true
            },
            {
                "position": 34,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/wheusaugppa/y3h7ocdn6g/pcxephu/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=8RQDIN&utm_source=home&utm_medium=recent&utm_term=91303",
                "show_on_mobile": true
            },
            {
                "position": 35,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/1h0kv1v995a/ti7e7j9vrk/o8ssq59/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=J1WD65&utm_source=home&utm_medium=recent&utm_term=174707",
                "show_on_mobile": true
            },
            {
                "position": 36,
                "image_url": "https://ioffer-assets.oss-eu-west-1.aliyuncs.com/as/variants/1phj57pa5ys/efr5fxm862/tp4wihn/bf/9536ee218c/6feedf26a1/ba46bbbc14/a0e225ae18/4f3f620947/c062ca7230/57",
                "image_title": "",
                "tile_name": "",
                "tile_url": "/products_s?sid=KUIX3F&utm_source=home&utm_medium=recent&utm_term=91311",
                "show_on_mobile": true
            }
        ]
    }
  end
end
