require 'shared/form_action_helper'
require 'rack/test'

module ProductsSpecHelper
  extend ActiveSupport::Concern
  extend FormActionHelper


  def cleanup_spree_products
    ::Spree::Product.all.each(&:really_destroy!)
  end

  def cleanup_categories
    ::Retail::SiteCategory.delete_all
    @site_categories = nil
    ::Spree::Taxon.delete_all
  end

  ###########################################

  def setup_all_for_posting_products
    # ::Spree::Product.rebuild_index!(false) # TODO: restore when elasticsearch setup
    Spree::Taxon.delete_all
    ::Spree::CategoryTaxon.find_or_create_categories_taxon
    setup_locale_records
    setup_category_taxons( [:clothing_category_taxon, :level_two_category_taxon, :level_three_category_taxon, :home_taxon, :consumer_electronics_taxon] )
    setup_site_categories('ioffer', [:level_one_site_category, :level_two_site_category, :level_three_site_category], true )
    setup_option_types_and_values
    setup_shipping_and_payment_methods
    setup_phantom_sellers
  end

  def setup_locale_records
    zone_na = find_or_create(:zone_north_america, :name)
    zone_na.update(default_tax: true)

    countries = [:country_us, :country_jp, :country_cn, :country_gb, :country_fr].collect do|factory_key|
      find_or_create(factory_key, :iso)
    end
    us_country = countries.first
    stock_loc = Spree::StockLocation.find_or_create_by(active: true) do|r|
      r.name = 'default'
      r.country_id = us_country.id
    end
    stock_loc.update(default: true)
  end

  # @category_taxon_factory_keys <Array of symbols> list of factory keys that represent a path of multiple levels.
  def setup_category_taxons(category_taxon_factory_keys)
    Rails.cache.delete Spree::CategoryTaxon::TOP_LEVEL_CATEGORIES_CACHE_KEY
    @categories_taxon = ::Spree::CategoryTaxon.find_or_create_categories_taxon
    current_node = @categories_taxon
    @category_taxons = category_taxon_factory_keys.collect do|factory_key|
      t =  find_or_create(factory_key, :name) do|new_record|
        new_record.parent_id = current_node.id
      end
      t.move_to_child_of( current_node )
      current_node = t
    end
  end

  def setup_ioffer_categories
    categories_taxon = Spree::CategoryTaxon.root
    ["Women's Clothing", "Men's Clothing", "Sneakers", "Handbags", 'Bags & Purses', "Jewelry",
      "Watches", "Sunglasses", "Makeup", "Women's Shoes", "Accessories" ].each do|cat_name|
        ioffer_category = Ioffer::Category.find_or_create_by(name: cat_name)
        taxon = Spree::Taxon.find_or_create_by(name: cat_name) 
        taxon.taxonomy_id ||= categories_taxon.taxonomy_id
        taxon.save
        taxon.move_to_child_of( categories_taxon )
        ioffer_category.category_to_taxons.find_or_create_by(taxon_id: taxon.id)
      end
  end

  def setup_ioffer_brands
    [{"name"=>"gucci", "presentation"=>"Gucci", "position"=>1},
      {"name"=>"louisvuitton", "presentation"=>"Louis Vuitton", "position"=>2},
      {"name"=>"nike", "presentation"=>"Nike", "position"=>3},
      {"name"=>"thenorthface", "presentation"=>"The North Face", "position"=>4},
      {"name"=>"coach", "presentation"=>"Coach", "position"=>5},
      {"name"=>"adidas", "presentation"=>"Adidas", "position"=>6},
      {"name"=>"off-white", "presentation"=>"Off-White", "position"=>7},
      {"name"=>"prada", "presentation"=>"Prada", "position"=>8},
      {"name"=>"yvessaintlaurent", "presentation"=>"Yves Saint Laurent", "position"=>9},
      {"name"=>"tiffany", "presentation"=>"Tiffany", "position"=>10},
      {"name"=>"chanel", "presentation"=>"Chanel", "position"=>11},
      {"name"=>"michaelkors", "presentation"=>"Michael Kors", "position"=>12},
      {"name"=>"burberry", "presentation"=>"Burberry", "position"=>13},
      {"name"=>"jordan", "presentation"=>"Jordan", "position"=>14},
      {"name"=>"cartier", "presentation"=>"Cartier", "position"=>15},
      {"name"=>"hermes", "presentation"=>"Hermes", "position"=>16},
      {"name"=>"bulgari", "presentation"=>"Bulgari", "position"=>17},
      {"name"=>"yeezy", "presentation"=>"Yeezy", "position"=>18},
      {"name"=>"bape", "presentation"=>"Bape", "position"=>19},
      {"name"=>"rayban", "presentation"=>"Ray Ban", "position"=>20}].each do|ar|
        Ioffer::Brand.find_or_create_by( name: ar['name']) do|b|
          b.presentation = ar['presentation']
          b.position = b['position']
        end
      end
  end

  ##
  # @site_category_factory_keys <Array of symbols> list of factory keys that represent a path of multiple levels.
  def setup_site_categories(site_name, site_category_factory_keys, mapping_to_category_taxons = true) 
    ::Retail::SiteCategory.delete_all
    retail_site = Retail::Site.find_or_create_by(name: site_name) do|site|
      site.domain = "#{site_name.downcase}.com"
    end
    current_node = ::Retail::SiteCategory.root_for(site_name)
    categories_taxon = ::Spree::CategoryTaxon.find_or_create_categories_taxon.children.try(:first)
    @site_categories = []
    parent_id = current_node.id
    site_category_factory_keys.each do|factory_key|
      t = create(factory_key, site_name: site_name, parent_id: parent_id,
        mapped_taxon_id: mapping_to_category_taxons ? categories_taxon.try(:id) : nil)
      categories_taxon = categories_taxon.children.first if mapping_to_category_taxons && categories_taxon
      t.move_to_child_of( current_node )
      current_node = t
      parent_id = t.id
      @site_categories << t
    end
    @site_categories
  end

  ##
  # Basic Spree::OptionType and OptionValue
  def setup_option_types_and_values
    Spree::OptionValue.delete_all
    Spree::OptionType.delete_all
    %w(color size brand material).each do|ot_name|
      ot = find_or_create("option_type_#{ot_name}".to_sym, :name)
      # ensure enough sample OptionValue
      ::Spree::OptionValue::SAMPLE_VALUES[ot_name.to_sym].each do|ov_value|
        ot.option_values.where(name: ov_value.titleize).first || create("option_value_#{ov_value.downcase}", option_type: ot)
      end
    end
    # ::Spree::OptionValue.import # TODO: ES double check

    position = 1
    ::Spree::OptionType.where(name: %w|color size|).each do|option_type|
      @category_taxons.each do|ct|
        ::Spree::RelatedOptionType.find_or_create_by!(
          record_type:'Spree::Taxon', record_id: ct.id, option_type_id: option_type.id) do|record|
          record.position = position
        end
      end
      position += 1
    end
  end

  def setup_ioffer_payment_methods
    Ioffer::PaymentMethod.delete_all
    ["PayPal",
      "Credit Card, Visa/MasterCard",
      "Apple Pay",
      "Google Pay",
      "Alipay",
      "WeChat",
      "WorldPay",
      "ipaylinks",
      "TransferWise",
      "Western Union",
      "BitCoin",
      "cash",
      "paysend",
      "ScoinPay",
      "ping"].each do|name|
        pm = Ioffer::PaymentMethod.find_or_initialize_by(name: name)
        pm.is_user_created = false
        pm.save
      end
  end

  def setup_shipping_and_payment_methods
    Spree::PaymentMethod.delete_all
    Spree::ShippingMethod.delete_all
    Spree::Calculator.delete_all
    Spree::TaxRate.delete_all

    tax_category = Spree::TaxCategory.find_or_create_by(name: 'Default')
    calc = Spree::Calculator.find_or_create_by(type:'Spree::Calculator::DefaultTax') do|r|
      r.calculable_type = 'Spree::TaxRate'
    end
    tax_rate = Spree::TaxRate.find_or_create_by(name:'No Tax') do|r|
      r.amount = 0
      r.calculator = calc
      r.tax_category = tax_category
      r.zone_id = Spree::Zone.first.id
      r.included_in_price = true
    end
    
    Spree::ShippingCategory.find_or_create_by(name: 'Default')
    Spree::TaxCategory.find_or_create_by(name: 'Default') do|tc|
      tc.is_default = true
    end

    Spree::PaymentMethod.populate_with_common_payment_methods
    Spree::ShippingMethod.populate_with_common_shipping_methods
    Spree::ShippingMethod.all.each do|sm| 
      sm.tax_category_id ||= tax_category.id; 
      sm.save
      Spree::Calculator.find_or_create_by(calculable_type: 'Spree::ShippingMethod', calculable_id: sm.id) do|c|
        c.type = 'Spree::Calculator::Shipping::FlatPercentItemTotal'
        c.preferences = {:flat_percent=>0.0}
      end  
    end
  
    Spree::Zone.all.each do|zone|
      Spree::ShippingMethod.all.each{|sm| zone.shipping_method_zones.create(shipping_method_id: sm.id) }
    end
  end

  #################################
  # Capybara

  def fill_into_product_form(product_attr)
    product_attr.each_pair do|k, v|
      next if v.nil?
      begin
        if v.is_a?(Array)
          v.each do|sub_v|
            if sub_v.is_a?(Hash)
              sub_v.each_pair do|sub_v_k, sub_v_v|
                xpath_field = find(:xpath, "//*[@name='product[#{k}][]#{sub_v_k}']")
                if sub_v_k.to_s == 'currency'
                  xpath_field.select(sub_v_v)
                else
                  xpath_field.set(sub_v_v)
                end
              end
            end
          end
        else
          find(:xpath, "//*[@name='product[#{k}]']").set(v )
        end
      rescue Capybara::ElementNotFound
        # puts "** Cannot find product field #{k}"
      end
    end
  end

  # @sample_image_path <File or IO> for uploading image
  # @options The options that's passed onto check_product_against.
  #   :auto_ensure_available
  # @return <Spree::Product>
  def post_product_via_pages(user, product_key, extra_attributes = {}, sample_image_path = nil, options = {})
    auto_ensure_available = options[:auto_ensure_available]
    auto_ensure_available ||= true
    auto_ensure_user_id = options[:auto_ensure_available]
    auto_ensure_user_id ||= true

    product_attr = attributes_for(product_key).merge(extra_attributes)
    visit new_admin_product_path(form:'form_in_one')
    expect(page.driver.status_code).to eq 200

    fill_into_form(['product', product_attr] )
    if sample_image_path
      find_all(:xpath, "//input[@name='product[uploaded_images][][attachment]']").last.attach_file(sample_image_path)
    end
    click_on('Create')

    product = ::Spree::Product.where(user_id: user.id).last
    expect(product).not_to be_nil
    expect(product.master).not_to be_nil
    expect(product.master.user_id).to eq product.user_id
    if product_attr[:taxon_ids].present?
      current_taxon_ids = product.taxons.collect(&:id)
      product_attr[:taxon_ids].split(',').each do|_tid|
        expect(current_taxon_ids).to include(_tid.to_i )
      end
    end
    if (images = other_attributes[:images] || other_attributes[:uploaded_images] ).present?
      expect(product.gallery.images.size).to eq(images.size) if images
    end
    expect(product.name).to eq(product_attr[:name])
    expect(product.description[0,20] ).to eq(product_attr[:description][0,20] )
    if product.price.to_f > 0.0
      master_price = other_attributes[:price]
      if (price_attr = other_attributes[:price_attributes] ).present?
        price_attr.each do|price_h|
          next unless price_h[:amount]
          if price_h[:currency].blank? || price_h[:currency] ==  Spree::Config[:currency]
            puts "  Assign this as master_price #{price_h}" if master_price.nil?
            master_price ||= price_h[:amount]
          else
            puts "  Got price of #{price_h} ?"
            expect( product.prices.where(currency: price_h[:currency], amount: price_h[:amount]).first ).not_to be_nil
          end
        end
      end
      expect(product.price).to eq master_price
    end

    product.available_on = Time.now if auto_ensure_available && product.available_on.nil?
    if auto_ensure_user_id
      product.user_id = user.id
      product.save

      product.master.user ||= product.user
      product.master.save
    end
    visit product_path(product)
    expect(page.driver.status_code).to eq 200

    product
  end

  # @other_attributes - 2nd step after created product, and form attributes to
  #   :images = Provide image paths like { images:[ '/shoppn/test.jpg'  ]}
  # @options The options that's passed onto check_product_against.
  #   :generate_option_value_combos [Boolean] default true
  def post_product_via_requests(user, product_key, other_attributes = {}, options = {})
    set_user_listing_policy_agreement(user.id)

    visit new_admin_product_path
    
    expect(page).to have_xpath("//form[@id='new_product']")

    product_attr = attributes_for(product_key)

    product_before = Spree::Product.last

    attr_taxon_ids = product_attr[:taxon_ids].is_a?(Array) ? 
      product_attr[:taxon_ids].collect(&:to_i) : 
      product_attr[:taxon_ids].to_s.split(',').collect(&:to_i).sort
    combos = nil
    combo_option_value_ids = nil
    related_option_types = nil
    if attr_taxon_ids.present?
      taxons = Spree::Taxon.where(id: attr_taxon_ids).all
      related_option_types = taxons.collect(&:closest_related_option_types).flatten.uniq
      product_attr[:option_type_ids] = related_option_types.collect{|_ot| _ot.id.to_s } if product_attr[:option_type_ids].blank?
      combos = options[:generate_option_value_combos] != false ? generate_option_value_combos(taxons) : nil
      combo_option_value_ids = combos.collect{|a| a.collect(&:to_s).join(',') } if combos
    end

    within '#new_product' do
      fill_into_product_form(product_attr.merge(other_attributes) )
      fill_into_product_form(option_type_ids: taxons.first.option_types.collect(&:id).collect(&:to_s).join(',') )
      combos.to_a.flatten.uniq.each do|ov_id|
        page.find_all("input[@name='option_value_id_#{ov_id.is_a?(Array) ? ov_id.collect(&:to_s).join(',') : ov_id}']").each(&:check)
        page.find_all("input[@name='option_value_id_#{ov_id.is_a?(Array) ? ov_id.reverse.collect(&:to_s).join(',') : ov_id}']").each(&:check)
      end if combos
      combo_option_value_ids.each do|combo_value_ids|
        checkbox_xpath = "*[@value='#{combo_value_ids.strip}']"
        checkbox_xpath2 = "*[@value='#{combo_value_ids.split(',').reverse.join(',').strip}']"
        checkbox = page.find_all(checkbox_xpath).first || page.find_all(checkbox_xpath2).first
        if checkbox
          checkbox.check
          expect(checkbox).to be_checked
        end
      end if combo_option_value_ids
      if related_option_types.present? && (ot_input = page.find("*[@name='product[option_type_ids]']") )
        ot_input.set( related_option_types.collect{|ot| ot.id.to_s }.join(',') ) if ot_input['value'].blank?
      end
      click_button("Create")
    end

    # post admin_products_path(product: product_attr, combo_option_value_ids: combo_option_value_ids)

    product_after = Spree::Product.last
    expect(product_after).not_to be_nil
    expect(product_after.user_id).to eq user.id
    expect(product_after.master.prices.present?).to be_truthy
    expect(product_after.master.price).to eq product_attr.merge(other_attributes)[:price]
    if related_option_types
      puts "  resulting option_types: #{product_after.option_types.collect(&:name) }"
      after_option_type_ids = product_after.option_types.collect(&:id)
      expect( related_option_types.all?{|_ot| after_option_type_ids.include?(_ot.id) } ).to be_truthy
    end
    
    if combos # somehow correct parameters just don't work
      expect( product_after.variants.count >= combos.size ).to be_truthy
    end

    product_attr.merge!(other_attributes)
    # convert array to joint string
    [:option_type_ids, :taxon_ids].each do|k|
      product_attr[k] = product_attr[k].collect(&:to_s).join(',') if product_attr[k].is_a?(Array)
    end

    put admin_product_path(id: product_after.id, product: product_attr )

    product_after.reload
    if attr_taxon_ids.present?
      product_taxon_ids = product_after.taxons.collect(&:id).sort
      expect(product_taxon_ids).to eq attr_taxon_ids
    end

    # Spree 4 has product's image upload splitted to later steps of creation path
    # POST "/admin/products/punk-style-platform-women-ankle-boots-women-s-motorcycle-boot-3369/images"  {"authenticity_token"=>"FY7gzTEVSXUflGobeYFH2UchOmeBHYXGRu+dvpcGvTOpxmo/oZqzP39Ys934jY5E0UCK2BtYjxBICdKF2Te2gw==", "image"=>{"attachment"=>#<ActionDispatch::Http::UploadedFile:0x00007fe4d50fd0e0 @tempfile=#<Tempfile:/var/folders/_q/7y1wj4j15vdfg8df0g5b8l2c0000gn/T/RackMultipart20200814-7649-1v3kg47.jpg>, @original_filename="12241-f7b6da-640x640.jpg", @content_type="image/jpeg", @headers="Content-Disposition: form-data; name=\"image[attachment]\"; filename=\"12241-f7b6da-640x640.jpg\"\r\nContent-Type: image/jpeg\r\n">, "viewable_id"=>"43056", "alt"=>""}, "button"=>"", "product_id"=>"punk-style-platform-women-ankle-boots-women-s-motorcycle-boot-3369"}

    images = other_attributes.delete(:images) || []
    uploaded_images = []
    old_images_count = product_after.master.images.count
    images.each do|sample_image_path|
      mime_type = "image/#{sample_image_path.match(::Spree::Image::IMAGE_EXTENSION_REGEXP).try(:[], 1) || 'jpg'}"
      image_file = fixture_file_upload(sample_image_path, mime_type)
      post admin_product_images_path(product_id: product_after.id, image: {
          attachment: image_file, viewable_id: product_after.master.id }
        )
    end

    product_after.reload

    product = check_product_against(user, product_key, other_attributes, options)
    expect(product.images.count).to eq(uploaded_images.size)

    product
  end

  ##
  # Join process to sign up basic user and post 1st product
  def signup_seller_and_post_product(user_factory_key = :basic_user, product_factory_key = :basic_product)
    seller = signup_sample_user(user_factory_key)
    select_store_payment_methods(seller)
    set_user_listing_policy_agreement(seller.id)
    Spree::Config.set(require_master_price: false)

    post_product_via_requests(seller, product_factory_key) # can add other_attributes w/ option_type_ids shown in variants_spec)
  end

  def populate_products_for_user(user, how_many = 5)
    products = []
    base_attr = attributes_for(:basic_product)
    base_attr[:user_id] = user.id
    1.upto(how_many) do|i|
      product = Spree::Product.create(base_attr.merge(name: base_attr[:name] + " #{i}", sku:"BASE#{i}" ))
      new_variant = product.variants.create(price: 21.3, option_values: product.option_types.collect{|ot| ot.option_values.first } )

      products << product.reload
    end
    expect(products.find_all(&:valid?).size ).to eq(how_many)

    products
  end

  def populate_variants_for(product)
    first_option_type = product.option_types.first
    second_option_type = product.option_types.find{|ot| ot.id != first_option_type.id } 

    if Spree::Product::ALLOW_TO_CHANGE_OPTION_TYPES_AFTER
      first_option_type = ::Spree::OptionType.first
      second_option_type = ::Spree::OptionType.last

      page.driver.put spree.admin_product_path(id: product.slug, product: {
          option_type_ids: "#{first_option_type.id},#{second_option_type.id}"
      })
      product.reload
      expect( product.option_types.collect(&:id).include?(first_option_type.id) ).to be_truthy
      expect( product.option_types.collect(&:id).include?(second_option_type.id) ).to be_truthy
    end
    ov_count = [first_option_type.option_values.count, second_option_type&.option_values&.count.to_i, 4].max
    first_list_option_value_ids = first_option_type.option_values.limit(ov_count)
    second_list_option_value_ids = second_option_type&.option_values.try(:limit, ov_count) || []
    0.upto(ov_count - 1) do|i|
      page.driver.post spree.admin_product_variants_path(product_id: product.slug, variant: {
          price: product.price.to_f, cost_currency: 'USD',
          option_value_ids: [first_list_option_value_ids[i], second_list_option_value_ids[i] ].compact
      })
    end
    product.reload
  end

  ##
  # General generation of combos for provided taxons w/ their related option types
  # @taxons [Array of Taxon or :factory_key_symbol or taxon_id]
  # @option_type_to_count_of_option_values [Hash of option_type_id to either Integer or Range]
  # @return [Array of Array of option_value_ids]
  def generate_option_value_combos(taxons, option_type_to_count_of_option_values = {}, &block)
     # opton_type_id to option value ids
    taxon_id_to_option_values = {}
    taxons.each do|_t|
      actual_taxon = if _t.is_a?(Spree::Taxon)
          _t
        elsif _t.class == Symbol
          find_or_create(_t, :name)
        else
          Spree::Taxon.find_by(id: _t)
        end
      if actual_taxon
        actual_taxon.closest_related_option_types.each do|ot|
          count = option_type_to_count_of_option_values[ot.id] || rand(2..5)
          taxon_id_to_option_values[ot.id] = ot.option_values.limit( count || 1 )
          yield ot, count if block_given?
        end
      end
    end

    selected_ovs = taxon_id_to_option_values.values
    combos = []
    selected_ovs[0].to_a.each do|first_ov|
      combos << [first_ov.id] if selected_ovs[1].nil?
      selected_ovs[1].to_a.each do|second_ov|
        combos << [first_ov.id, second_ov.id] if selected_ovs[2].nil?
        selected_ovs[2].to_a.each do|third_ov|
          combos << [first_ov.id, second_ov.id, third_ov.id]
        end
      end
    end
    combos
  end

  ##
  # Generate random combos of color plus size, and saves to product.  Then checks the use of 
  # product.user_variant_option_value_ids against expected option values and variants.
  # @return [Array of Array] a list of the option value combo array, for example, 
  #   [ [$optionValue1OfOptionType1, $optionValue1OfOptionType2], [$optionValue2OfOptionType1, $optionValue2OfOptionType2] ]
  def generate_color_and_size_combos(product, count_of_color_ovs = nil, count_of_size_ovs = nil)
    color_ot = find_or_create(:option_type_color, :name)
    size_ot = find_or_create(:option_type_size, :name)

    # Add new
    puts "    Saving option values"
    first_param = generate_option_value_combos(product.taxons) do|ot, count|
      puts "    * #{ot.name} (#{count})"
    end

    product.user_variant_option_value_ids = { product.user_id => first_param }
    product.save_option_values!
    product.reload
    product.variants.reload

    check_matching_option_values(product, first_param)

    puts "    Another call to save_option_values!"
    product.save_option_values!
    product.reload
    product.variants.reload

    check_matching_option_values(product, first_param)

    first_param
  end

  private

  ##
  # @options
  #   :auto_ensure_available <Boolean> default true; somehow form submission has product created but
  #     available_on stays nil.  Never see such behavior in real run.
  #   :auto_ensure_user_id <Boolean> default true; somehow product create cannot set user_id
  #
  def check_product_against(user, product_key, other_attributes = {}, options = {})
    auto_ensure_available = options[:auto_ensure_available]
    auto_ensure_available ||= true
    auto_ensure_user_id = options[:auto_ensure_available]
    auto_ensure_user_id ||= true

    product_attr = attributes_for(product_key).merge(other_attributes)
    product = ::Spree::Product.where(user_id: user.id).last
    expect(product).not_to be_nil
    expect(product.master).not_to be_nil

    if product_attr[:taxon_ids].present?
      current_taxon_ids = product.taxons.collect(&:id)
      attr_taxon_ids = product_attr[:taxon_ids].is_a?(Array) ? 
        product_attr[:taxon_ids].collect(&:to_i) : 
        product_attr[:taxon_ids].to_s.split(',').collect(&:to_i).sort
      attr_taxon_ids.each do|_tid|
        expect(current_taxon_ids).to include(_tid.to_i )
      end
    end
    if (images = other_attributes[:images] || other_attributes[:uploaded_images] ).present?
      expect(product.gallery.images.size).to eq(images.size) if images
    end
    if (brand = Spree::OptionType.brand)
      check_collected_option_values(product_attr, product, brand)
    else
      expect(product.name).to eq(product_attr[:name])
    end
    expect(product.description[0,20] ).to eq(product_attr[:description][0,20] )
    if product.price.to_f > 0.0
      default_currency_price = nil
      if (price_attr = other_attributes[:price_attributes] ).present?
        price_attr.each do|price_h|
          next unless price_h[:amount]
          if price_h[:currency].blank? || price_h[:currency] == Spree::Config[:currency]
            default_currency_price ||= price_h[:amount]
          else
            puts "  Got price of #{price_h} ?"
            expect( product.master.prices.where(currency: price_h[:currency], amount: price_h[:amount]).first ).not_to be_nil
          end
        end
      end
      # master price still overrides
      if product_attr[:price].to_f.zero? && default_currency_price
        expect(product.price).to eq default_currency_price
      end
    end

    product.available_on = Time.now if auto_ensure_available && product.available_on.nil?
    if auto_ensure_user_id
      product.user_id = user.id
      product.save

      product.master.user ||= product.user
      product.master.save
    end

    visit product_path(product)
    expect(page.driver.status_code).to eq 200

    product
  end

  ##
  # If the +option_type+ has option values that should be stripped, product.name should change accordingly,
  # different from product_attr[:name].
  def check_collected_option_values(product_attr, product, option_type)
    return unless option_type.option_values.present?
    original_name = product_attr[:name].downcase
    words_to_strip = []
    if ::Spree::OptionValue::STRIP_FROM_ATTRIBUTES
      # puts "  '#{option_type.presentation}' to strip: #{option_type.option_values.collect(&:presentation) }"
      option_type.option_values.each do|b|
        if product_attr[:name] =~ /\b#{b.presentation}\b/i
          words_to_strip << b.presentation
          original_name.gsub!(b.presentation.downcase, '')
        end
        product.name.match(/\b#{b.presentation}\b/i ).nil?
      end
      original_name.strip!
      expect(product.name.downcase).to eq(original_name)
    end
    if words_to_strip.size > 0 # got stripped
      variant_with_brand = product.variants_including_master.find do|var|
        var.option_values.find{|ov| option_type.option_values.collect(&:id).include?(ov.id) }
      end
      expect(variant_with_brand).not_to be_nil
    end
  end

  def check_matching_option_values(product, param)
    expect(product.variants.not_by_phantom_sellers.count).to eq param.size
    param.each do|pair_ov_ids|
      matching_variant = product.variants.not_by_phantom_sellers.includes(:option_value_variants).find do|v|
        v.option_value_variants.collect(&:option_value_id).sort == pair_ov_ids.sort
      end
      expect(matching_variant).not_to be_nil
      expect(matching_variant.user_id).to eq product.user_id
    end
  end

  protected

  def set_sample_data
    let(:sample_image_url) { 'https://ioffer.com/android-chrome-192x192.png' }
    let(:sample_fixture_file_name) { 'nike_air.png' }
    let(:sample_image_path) { Rails.root.join('spec/fixtures/files', sample_fixture_file_name).to_s }
    let(:sample_product_image) { fixture_file_upload(sample_fixture_file_name) }
    let(:sample_image_content) { File.read(sample_product_image.tempfile) }
  end

  def set_user_listing_policy_agreement(user_id)
    User::Stat.fetch_or_set(user_id, Spree::User::AGREED_TO_LISTING_POLICY) do 
      Time.now.to_s(:db)
    end
  end

  def display_product_variants(product)
    product.variants.includes(:option_values => [:option_type], :variant_adoptions => [:user=>[:role_users]]).each do|v|
      puts '(%9d) by %8s (%8d) | preferred %7s | %s | %s of OT %s' % [v.id, v.user.username, v.user_id, v.preferred_variant_adoption&.id.to_s, v.sku_and_options_text, v.option_values.collect(&:id).to_s, v.option_values.collect{|ov| ov.option_type.name }.to_s]
      if Spree::Variant::USE_VARIANT_ADOPTIONS
        v.variant_adoptions.each do|va|
          puts '        * VAdopt (%d) by %60s, phantom? %5s | $%.2f' % [va.id, va.user.to_s, va.user&.phantom_seller?.to_s, va.price]
        end
      end
    end.class
  end
end