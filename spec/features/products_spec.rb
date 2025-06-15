require 'rails_helper'
require 'shared/session_helper'
require 'shared/products_spec_helper'
require 'shared/users_spec_helper'

include SessionHelper
include ProductsSpecHelper
include UsersSpecHelper

RSpec.describe ::Spree::Product do
  before(:all) do
    cleanup_categories
    setup_all_for_posting_products
    Capybara.ignore_hidden_elements = false
    ::Spree::User.delete_all
    setup_subscriptions
    setup_phantom_sellers
  end

  after(:all) do
    cleanup_spree_products
  end

  set_sample_data

  describe 'create product by code', type: :feature do
    # routes { Spree::Core::Engine.routes }
    let :first_user_attr do
      attributes_for(:another_user)
    end
    let :user_attr do
      attributes_for(:basic_user)
    end
    [:basic_seller, :phantom_seller].each do|key|
      let key do
        user = find_or_create(key, :email) do|u|
          u.password = TEST_USER_PASSWORD
        end
        setup_paypal(user)
        user
      end
    end

    it 'Create Product w/ Images' do
      [basic_seller, phantom_seller].each do|seller|
        create_and_check_product(:basic_product, seller)
        create_and_check_product(:consumer_electronics_product, seller)
      end
    end

    it 'Option Types and Values' do
      puts 'Try Posting Product w/ Option Types and Values -------------------------'
      product = find_or_create(:basic_product, :name)
      seller = find_or_create(:seller, :email) do|u|
        u.password = TEST_USER_PASSWORD
      end

      sign_in_from_form(seller)
      check_after_sign_in_path(seller)
      product.user_id = seller.id
      product.save

      puts "1) Adding colors & sizes to product:"
      color_ot = find_or_create(:option_type_color, :name)
      all_color_ovs = color_ot.option_values.all.shuffle
      count_of_color_ovs = [3, all_color_ovs.size - 2].min
      first_param = generate_color_and_size_combos(product, count_of_color_ovs)

      second_param = first_param.clone.shuffle
      1.upto(3){ second_param.pop }
      puts "2) Deleting some combos: #{second_param.sort}\n   old: #{first_param.sort}"
      product.user_variant_option_value_ids = { product.user_id => second_param }
      product.save_option_values!
      product.reload
      product.variants.reload

      check_matching_option_values(product, second_param)

      third_param = second_param.clone.shuffle
      third_param << [ all_color_ovs[count_of_color_ovs].id ]
      third_param << [ all_color_ovs[count_of_color_ovs + 1].id ]
      puts "3) Mix some combos w/ picked of other single option values: #{third_param.sort}\n   old: #{second_param.sort}"

      product.user_variant_option_value_ids = { product.user_id => third_param }
      product.save_option_values!
      product.reload
      product.variants.reload

      check_matching_option_values(product, third_param)

      puts "4) Soft delete seller"
      seller.soft_delete!
      check_bad_user(seller)

      product2 = find_or_create(:basic_product, :name) do|_p|
        _p.name << " of user #{seller.id} 2"
        _p.user_id = seller.id
      end
      expect(product2&.user_id).to eq seller.id
      expect(product2.iqs).to be <= 0

      product2.images.create(attachment:{ io: StringIO.new(sample_image_content), filename: sample_fixture_file_name }, viewable: product2.find_or_build_master )
      product2.reload
      expect(product2.iqs).to be <= 0

      product.reload
      expect(product.iqs).to be <= 0

      puts "5) Restore seller"
      seller.reload
      seller.restore_status!
      expect(seller.seller_rank).to be > 0

      product.reload
      expect(product.iqs).to be > 0
      product2.reload
      expect(product2.iqs).to be > 0

    end
  
  end # create product by code

  ##########################
  # Unless focused to use test-driven-development, painful to rewrite tests upon 
  # page and form changes.
=begin
  describe 'Create Product Via Page Request' do

    it 'Create Product with Images', post_with_images: true do
      puts 'Product with Images, Prices, and brand ---------------------------'
      user = signup_sample_user(:basic_user)
      set_user_listing_policy_agreement(user.id)

      price_attr = [{currency: 'USD', amount: 50.0},
        {currency: 'EUR', amount: 48.0}, {currency: 'JPY', amount: 4500.0 } ]
      product_attr = attributes_for(:basic_product)
      product_attr[:price_attributes] = price_attr

      product_before = ::Spree::Product.where(user_id: user.id).last
      no_price_product_attr = attributes_for(:no_price_product)

      puts '-- Try posting product w/o price'
      Spree::Config.set(require_master_price: true)

      post admin_products_path(product: no_price_product_attr)
      last_product = ::Spree::Product.where(user_id: user.id).last
      expect(last_product).to be_nil

      puts '  +- Turn require_master_price false, should proceed'
      Spree::Config.set(require_master_price: false)
      post admin_products_path(product: no_price_product_attr)
      last_product = ::Spree::Product.where(user_id: user.id).last
        
      expect(last_product).not_to be_nil
      any_price_with_amount = last_product.prices.find{|price| price.amount.to_f > 0 }
      expect(any_price_with_amount).to be_nil
    end

    it 'Post w/ price and brand in name', post_with_images: true do
      puts '-- Try posting w/ specified price, and brand'
      user = signup_sample_user(:basic_user)
      set_user_listing_policy_agreement(user.id)

      one_brand = ::Spree::OptionValue::SAMPLE_VALUES[:brand].first
      second_brand = ::Spree::OptionValue::SAMPLE_VALUES[:brand][1]
      brand_ot = ::Spree::OptionType.where(name:'brand').first
      brand_value = brand_ot.option_values.where(presentation: one_brand).first
      second_brand_value = brand_ot.option_values.where(presentation: second_brand).first
      shirt_product_name = attributes_for(:shirt_product)[:name]
      modded_name = shirt_product_name + ' ' + one_brand

      shirt_product = post_product_via_requests(user, :shirt_product, { price: 33.5, name: modded_name } )
      expect(shirt_product.price).to eq 33.5
      expect(shirt_product.master.prices.count).to eq 1

      if ::Spree::OptionValue::STRIP_FROM_ATTRIBUTES
        expect(shirt_product.name.downcase).to eq shirt_product_name.downcase
        expect(shirt_product.name.downcase.index(one_brand.downcase)).to be_nil
        expect(shirt_product.slug).to eq ( shirt_product_name.strip.downcase.gsub(/(\s+)/, '-') + "-#{shirt_product.id}" )

        ## Somehow the second change of name does not callback after_save
        # shirt_product.name << ' ' + one_brand
        # shirt_product.save
        # shirt_product.reload
        # expect(shirt_product.name.downcase.index(one_brand.downcase)).to be_nil

      else
        expect(shirt_product.name.downcase).to eq modded_name.downcase
        expect(shirt_product.name.downcase.index(one_brand.downcase)).not_to be_nil
        expect(shirt_product.slug).to eq ( modded_name.strip.downcase.gsub(/(\s+)/, '-') + "-#{shirt_product.id}" )
      end


      puts '-- Create some variant w/ option value'
      post admin_product_variants_path(product_id: shirt_product.id, variant:{ price: shirt_product.price, option_value_ids:[second_brand_value.id] } )
      shirt_product.variants.reload

      expect(shirt_product.variants.last.option_values.include?(second_brand_value) ).to be_truthy
      if ::Spree::OptionValue::STRIP_FROM_ATTRIBUTES
        expect(shirt_product.slug).to eq ( shirt_product_name.strip.downcase.gsub(/(\s+)/, '-') + "-#{shirt_product.id}" )
      else
        expect(shirt_product.slug).to eq ( modded_name.strip.downcase.gsub(/(\s+)/, '-') + "-#{shirt_product.id}" )
      end
    end

  end # create product via page requests
=end
  describe 'Takedown' do

    ##
    # Those /vp
    it 'Takedown Variant and Variant Adoption' do
      puts 'Takedown Variant and Variant Adoption --------------------'
      Spree::Product.es.rebuild_index!
      sellers = Spree::User.pick_phantom_sellers(3)
      seller = sellers.first
      setup_paypal(seller)

      puts '1) create product and in search index'
      product = find_or_create(:basic_product, :name) do|_p|
        _p.user_id = seller.id
      end
      product.generate_phantom_variants!(true, true) if product.variants.count == 0
      Spree::VariantAdoption.where(variant_id: product.variants_including_master_without_order.collect(&:id)).
        includes(user:[:store]).each do|va|
          setup_paypal(va.user)
      end
      product.auto_select_rep_variant! # variant after no longer trigger

      expect(product.phantom?).to be_truthy
      expect(product.rep_variant_id).not_to be_nil
      expect(product.select_best_variant.id).not_to eq product.master.id
      expect(product.rep_variant.user.phantom_seller?).to be_truthy


      # Add enough to be searchable
      product.rep_variant.images.create(attachment:{ io: StringIO.new(sample_image_content), 
        filename: sample_fixture_file_name }, viewable: product.find_or_build_master )
      product.update(iqs: 20, available_on: Time.now)

      # Create adoptions if needed
      initial_vp_adoptions_count = product.rep_variant.adoptions.count
      if initial_vp_adoptions_count.zero?
        sellers[1, sellers.size].each do|other_seller|
          product.rep_variant.adoptions.create( user_id: other_seller.id, 
            prices:[ Spree::AdoptionPrice.new(amount: product.price * 0.9, currency: product.currency) ] )
        end
        expect( product.rep_variant.adoptions.count ).to eq( sellers.size - 1)
      end

      puts '2) enforces a rep_variant_adoption'
      rep_variant_adoption = product.rep_variant_adoption
      expect(rep_variant_adoption.user.phantom_seller?).to be_truthy

      product.auto_select_rep_variant!

      product.reload
      expect(product.display_variant_adoption_code).not_to be_nil
      expect(product.display_variant_adoption).not_to be_nil

      # Now index and search
      check_product_in_search(product)

      original_vp = product.rep_variant
      original_ov_ids = original_vp.option_value_variants.collect(&:option_value_id).sort
      adoptions = original_vp.adoptions
      images = original_vp.images
      
      puts '3) takedown variant '
      product.rep_variant.takedown!
      
      product.reload
      expect(product.rep_variant_id).not_to eq(original_vp.id)
      expect(product.rep_variant).not_to be_nil
      expect(product.rep_variant.option_value_variants.collect(&:option_value_id).sort ).to eq( original_ov_ids )

      original_vp.reload
      expect( Spree::Variant.with_deleted.find(original_vp.id)&.deleted? ).to be_truthy

      new_vp_id = product.rep_variant.id
      new_vp_seller_id = product.rep_variant.user_id
      adoptions.each do|adoption|
        adoption.reload
        expect(adoption.variant_id).to eq( new_vp_id )
      end
      images.each do|image|
        image.reload
        expect(image.viewable_id).to eq( new_vp_id )
      end

      puts '4) takedown variant adoption'
      selected_display_va = product.display_variant_adoption
      selected_display_va.takedown!

      product.reload
      expect(product.display_variant_adoption_code).not_to be_nil
      expect(product.display_variant_adoption_code).not_to eq(selected_display_va.code)
      expect(selected_display_va.variant.deleted?).not_to be_truthy

      check_product_in_search(product)
    end
  end


  private

  def create_and_check_product(product_factory_key, seller)
    product = find_or_create(product_factory_key, :name) do|_p|
      _p.name << " of user #{seller.id}"
      _p.user_id = seller.id
    end
    expect(product).not_to be_nil
    expect(product.id).not_to be_nil
    expect(product.user_id).to eq seller.id

    if product.phantom? && (product.option_types.any?(&:color?) || product.option_types.any?(&:size?) )
      expect( product.variants_without_order.by_phantom_sellers.count ).to be >= 1
    end

    has_taxon_prices = product.taxons.first.taxon_prices.count > 0
    product.variants_without_order.each do|v|
      ad_q = v.variant_adoptions.by_phantom_sellers
      expect( ad_q.count ).to be >= 1
      ad_q.each do|va|
        if has_taxon_prices
          expect( product.is_price_within_range?(va.price.to_f) ).to be_truthy
        else
          expect( va.price.to_f ).to eq product.price.to_f
        end
      end
    end

    expect(product.iqs.to_i).to eq( product.user.test_or_fake_user_except_phantom? ? Spree::Product::TEST_IQS : 0)

    if product.variant_images.count > 0 # not sure factory has images
      expect(product.images_count).to eq product.variant_images.count
      if Spree::Product::SET_AVAILABLE_ON_INITIALLY
        expect(product.available_on).not_to be_nil
        expect(product.indexable?).to be_truthy
      else
        expect(product.available_on).to be_nil
        product.last_review_at = Time.now
        product.save
        expect(product.available_on).not_to be_nil
        expect(product.indexable?).to be_truthy
      end
    else
      expect(product.images_count).to eq 0
      expect(product.iqs.to_i).to eq(product.user.test_or_fake_user_except_phantom? ? Spree::Product::TEST_IQS : 0)
      expect(product.indexable?).to eq false
    end

    product.images.create(attachment:{ io: StringIO.new(sample_image_content), filename: sample_fixture_file_name }, viewable: product.find_or_build_master )

    product.reload
    expect(product.variant_images.count).to eq(1)
    expect(product.images_count).to eq(1)
    expect(product.iqs.to_i).to eq(product.overriding_iqs || Spree::Product::SINGLE_IMAGE_IQS)

    new_variant = product.variants.create(price: 21.3, option_values: product.option_types.collect{|ot| ot.option_values.first } )
    new_variant.images.create(attachment:{ io: StringIO.new(sample_image_content), filename: sample_fixture_file_name }, viewable: product.find_or_build_master )
    product.update(updated_at: Time.now + 1.second) # force after calls
    product.auto_select_rep_variant! # variant after no longer trigger

    product.reload
    expect(product.variant_images.reload.count).to eq(2)
    expect(product.images_count).to eq(2)
    unless product.overriding_iqs
      expect(product.iqs.to_i >= Spree::Product::SINGLE_IMAGE_IQS).to be_truthy
    end

    if seller.phantom_seller?
      expect(product.variants.by_phantom_sellers.count > 0).to be_truthy
    else
      expect(product.variants.by_phantom_sellers.count).to eq 0
    end
    expect(product.rep_variant_id).not_to be_nil
    if product.select_best_variant # needs Paypal
      expect(product.select_best_variant.id).not_to eq product.master.id
    end
    if seller.phantom_seller?
      expect(product.rep_variant.user.phantom_seller?).to be_truthy
    end

    # Like admin manual update
    product.update(iqs: 60)
    product.reload
    expect(product.iqs).to eq(60)

    expect(product.taxons.count).not_to eq 0
    if product.taxons.first.taxon_prices.size > 0
      price_amounts = product.taxons.first.taxon_prices.collect(&:price)
      product.variants_without_order.each do|v|
        v.variant_adoptions.by_phantom_sellers.includes(:default_price).each do|va|
          expect( price_amounts.include?(va.price) ).to be_truthy
        end
      end
    end
  end


  def check_product_in_search(product)
    expect(product.indexable?).to be_truthy
    product.es.update_document
    sleep(1) # multiple runs proved update time needed by search index
    search = Spree::Product.es.search(query:{ match:{ '_id': product.id } })
    expect(search.results.total).to eq(1)
    search_data = search.results.first['_source']
    current_json = product.as_indexed_json
    current_json.symbolize_keys!
    [:user_id, :name, :description, :user_id, :price, :taxon_ids, :option_type_ids, :option_value_ids, 
      :other_text, :best_price, :transaction_count, :recent_transaction_count].each do|key|
        formatted_value = key.to_s =~ /(price|total|amount)\Z/i ? search_data[key].to_f : search_data[key]
        expect( formatted_value ).to eq( current_json[key] ), "Expected #{key} = #{current_json[key]}, but got #{ search_data[key] }"
      end

    words = product.name.split(/\s+/).collect{|w| w.gsub(/([\W]+)/i, '') }
    visit products_path(keywords: words[0, 2].join(' ') )
    product_card = page.find_all("div[@id='product_#{product.id}']")[0]
    expect(product_card).not_to be_nil
    link = product_card.find_link
    expect(link).not_to be_nil
    expect(link['href'] ).to eq( '/vp/' + product.display_variant_adoption_slug )
  end


end