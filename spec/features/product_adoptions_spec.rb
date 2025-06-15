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

 
  describe 'Adopt product', type: :feature do

    it 'List Same Item Without Variant' do
      puts 'List Same Product Without Variant ------------------------------'
      puts "1) Seller w/ product"
      t = find_or_create(:consumer_electronics_taxon, :name)
      t.option_types = [ find_or_create(:option_type_one_color), find_or_create(:option_type_one_size) ]
      t.save

      seller = prepare_seller_with_product(:consumer_electronics_product, 
        name:'Leather Bag', taxon_ids:[t.id], option_type_ids: t.option_types.collect(&:id) )
      product = Spree::Product.where(user_id: seller.id).last
      required_option_types = product.option_types.find_all(&:required_to_specify_value?)
      expect(required_option_types).to eq( [] )
      expect(product.variants.count ).to eq(0)

      puts "2) Seller #2 list variants of some option values"
      seller2 = prepare_seller2

      visit admin_list_same_item_path(product)
      init_count_of_products_adopted = seller2.count_of_products_adopted

      seller2_price = product.price + 1.0
      post admin_list_variants_path(id: product.id, product:{variant_price: seller2_price}, shipping:'1-3')

      product.variants.reload
      # display_product_variants(product)

      if Spree::Variant::USE_VARIANT_ADOPTIONS
        expect( product.variants.adopted.where(user_id: seller2.id).count ).to eq(init_count_of_products_adopted)
        
        v = product.master
        expect( v.variant_adoptions.all?{|ad| ad.user_id == seller2.id || ad.user.phantom_seller? } ).to be_truthy
        if v.user.store.store_payment_methods.size > 0
          expect( v.preferred_variant_adoption ).to be_nil
        end
      else
        expect( product.variants.where(user_id: seller2).count ).to eq(init_count_of_products_adopted)
        expect( product.variants.where(user_id: seller2).all.collect(&:price).uniq ).to eq [seller2_price]

      end
      seller2.reload
      expect(seller2.count_of_products_adopted).to eq(init_count_of_products_adopted + 1)
    end

    it 'List Same Item With Colors and One Size' do
      puts 'List Same Item With Colors and One Size ------------------------------'
      puts "1) Seller w/ product"
      one_size = find_or_create(:option_type_one_size, :name)
      one_size.option_values.create(name:'one size', presentation:'One Size') if one_size.option_values.blank?
      t = find_or_create(:bags_and_purses_taxon, :name)
      t.option_types = [ find_or_create(:option_type_color), one_size]
      t.save

      seller = prepare_seller_with_product(:basic_product, 
        name:'Leather Bag', taxon_ids:[t.id], option_type_ids: t.option_types.collect(&:id) )
      product = Spree::Product.where(user_id: seller.id).last
      required_option_types = product.option_types.find_all(&:required_to_specify_value?)
      expect(required_option_types.size).to eq(1)

      one_size_option_value = product.option_types.find(&:size?).option_values.first
      color_option_values = product.option_types.find(&:color?).option_values.to_a.shuffle[0,3]
      puts " ... adding combos of #{color_option_values.size} colors x 1 size"

      first_param = color_option_values.collect{|color_ov| [color_ov.id, one_size_option_value.id] }

      product.user_variant_option_value_ids = { product.user_id => first_param }
      product.save_option_values!
      product.reload
      product.variants.reload

      # display_product_variants(product)

      expect(product.variants.size).to eq(color_option_values.size)

      puts "2) Seller #2 list variants of some option values"
      seller2 = prepare_seller2

      visit admin_list_same_item_path(product)
      init_count_of_products_adopted = seller2.count_of_products_adopted

      combo_option_value_ids = pick_subset_of_combo_option_value_ids(first_param)
      combo_option_value_strings = combo_option_value_ids.collect{|_combo| _combo.collect(&:to_s).join(',') }

      seller2_price = product.price + 1.0
      post admin_list_variants_path(id: product.id, product:{variant_price: seller2_price}, 
        combo_option_value_ids: combo_option_value_strings, shipping:'1-3')

      product.variants.reload
      # display_product_variants(product)

      if Spree::Variant::USE_VARIANT_ADOPTIONS
        check_variant_adoptions(product, seller2, combo_option_value_ids)

      else
        expect( product.variants.where(user_id: seller2).count ).to eq combo_option_value_ids.size
        expect( product.variants.where(user_id: seller2).all.collect(&:price).uniq ).to eq [seller2_price]

        seller2_options_map = product.options_map(seller2.id)
        combo_option_value_ids.each do|option_value_ids|
          expect( seller2_options_map.find_variants_of_option_values(option_value_ids) ).not_to be_nil
        end
      end
      seller2.reload
      expect(seller2.count_of_products_adopted).to eq(init_count_of_products_adopted + 1)
    end

    it 'List Same Product With Multiple Combos' do
      puts 'List Same Product With Multiple Combos ------------------------------'
      seller = prepare_seller_with_product() do|u|
        select_store_payment_methods(u)
      end

      product = Spree::Product.where(user_id: seller.id).last

      # Add new
      puts "1) Adding colors & sizes to product:"
      first_param = generate_color_and_size_combos(product)
      phantom_seller = find_or_create(:some_phantom_user, :username)
      phantom_seller.password = 'test1234'
      phantom_seller.save
      expect(phantom_seller.seller_rank).to be < seller.seller_rank

      if product.user_id != phantom_seller.id
        product.variants.reload.each do|v|
          v.update(user_id: phantom_seller.id)
        end
      end
      # display_product_variants(product)

      visit logout_path

      puts "2) Seller #2 list variants of some option values"
      seller2 = prepare_seller2
      expect(phantom_seller.seller_rank).to be < seller2.seller_rank


      visit admin_list_same_item_path(product)

      init_count_of_products_adopted = seller2.count_of_products_adopted

      combo_option_value_ids = pick_subset_of_combo_option_value_ids(first_param)
      combo_option_value_strings = combo_option_value_ids.collect{|_combo| _combo.collect(&:to_s).join(',') }

      seller2_price = product.price + 1.0
      puts "  adopt w/ #{combo_option_value_strings}, w/ price #{seller2_price}"
      post admin_list_variants_path(id: product.id, product:{variant_price: seller2_price}, 
        combo_option_value_ids: combo_option_value_strings, shipping:'1-3')

      product.reload
      product.variants.reload
      expect(product.best_variant).not_to be_nil
      expect(product.best_variant.preferred_variant_adoption).not_to be_nil

      seller2_va_count = product.variants.find_all{|v| v.variant_adoptions.where(user_id: seller2.id).count > 0 }.size
      expect(seller2_va_count).to eq combo_option_value_strings.size

      puts "  phantom_seller.id #{phantom_seller.id}"
      display_product_variants(product)

      best_variant_adoption = product.best_variant.preferred_variant_adoption
      best_rank_va = product.best_variant.variant_adoptions.sort(&:seller_based_rank_order).last
      if seller2_price < product.price
        expect(best_variant_adoption&.user_id).to eq seller2.id
        expect(best_variant_adoption&.price).to eq seller2_price
      else
        # adoptions excluding variant
        expect(best_variant_adoption&.user_id).to eq best_rank_va.user_id
        expect(best_variant_adoption&.price).to eq best_rank_va.price
      end

      if Spree::Variant::USE_VARIANT_ADOPTIONS
        check_variant_adoptions(product, seller2, combo_option_value_ids)
  
      else
        expect( product.variants.where(user_id: seller2).count ).to eq combo_option_value_ids.size
        expect( product.variants.where(user_id: seller2).all.collect(&:price).uniq ).to eq [seller2_price]

        seller2_options_map = product.options_map(seller2.id)
        combo_option_value_ids.each do|option_value_ids|
          expect( seller2_options_map.find_variants_of_option_values(option_value_ids) ).not_to be_nil
        end
      end

      seller2.reload
      expect(seller2.count_of_products_adopted).to eq(init_count_of_products_adopted + 1)

      puts "3) Seller #2 tries to adopt w/ combos outside of creator's variants"
      not_included_combo = []
      product.option_types.each do|ot|
        not_included_combo << ot.option_values.where('id NOT IN (?)', combo_option_value_ids.flatten ).first.id
      end
      # display_product_variants(product)
      puts "Compared w/ seller #2 (#{seller.id}) posting option values #{not_included_combo}"
      post admin_list_variants_path(id: product.id, product:{variant_price: seller2_price}, 
        combo_option_value_ids: [not_included_combo.collect(&:to_s).join(',') ], shipping:'1-3')

      product.variants.reload
      if Spree::Variant::USE_VARIANT_ADOPTIONS
        variants_adopted = product.variants.joins(:variant_adoption).all
        expect(variants_adopted.size).to eq combo_option_value_ids.size
        variants_adopted.each do|v|
          expect( v.variant_adoptions.count ).to eq 1
        end
      else
        expect( product.variants.where(user_id: seller2).count ).to eq combo_option_value_ids.size
        expect( product.variants.where(user_id: seller2).all.collect(&:price).uniq ).to eq [seller2_price]
      end
      seller2.reload
      expect(seller2.count_of_products_adopted).to eq(init_count_of_products_adopted + 1)

      outside_ot = Spree::OptionType.where("id NOT IN (?) and name != 'brand'", product.option_types.collect(&:id)).first
      if outside_ot
        puts "4) Seller #2 tries to adopt w/ outside option_types"
        post admin_list_variants_path(id: product.id, product:{variant_price: seller2_price}, 
          combo_option_value_ids: [ outside_ot.option_values.limit(2).collect{|ov| ov.id.to_s }.join(',') ], shipping:'1-3')
        if Spree::Variant::USE_VARIANT_ADOPTIONS
          variants_adopted = product.variants.joins(:variant_adoption).all
          expect(variants_adopted.size).to eq combo_option_value_ids.size
          variants_adopted.each do|v|
            expect( v.variant_adoptions.count ).to eq 1
          end
        else
          expect( product.variants.where(user_id: seller2).count ).to eq combo_option_value_ids.size
          expect( product.variants.where(user_id: seller2).all.collect(&:price).uniq ).to eq [seller2_price]
        end
      end

      puts '5) Comes seller3'
      visit logout_path
      seller3 = prepare_seller3

      visit admin_list_same_item_path(product)

      seller3_price = seller2_price * 0.9
      puts "  adopt w/ #{combo_option_value_strings}, w/ price #{seller3_price}"
      post admin_list_variants_path(id: product.id, product:{variant_price: seller3_price}, 
        combo_option_value_ids: combo_option_value_strings, shipping:'1-3')

      product.reload
      product.variants.reload
      display_product_variants(product)

      best_variant_adoption = product.best_variant.preferred_variant_adoption
      if seller3_price < seller2_price
        expect(best_variant_adoption.user_id).to eq seller3.id
        expect(best_variant_adoption.price).to eq seller3_price
      end
      
    end

  end # Adopt product

  private

  def prepare_seller_with_product(product_factory_key = :basic_product, other_attributes = {}, &block)
    a = attributes_for(product_factory_key)
    a.merge!(other_attributes)
    seller = find_or_create(:seller, :email) do|u|
      u.password = TEST_USER_PASSWORD
    end

    sign_in_from_form(seller)
    check_after_sign_in_path(seller)

    yield seller if block_given?
    
    product = Spree::Product.create(a.merge(user_id: seller.id))
    expect(product.user_id).to eq seller.id
    expect(product.master.user_id).to eq seller.id
    product.variants.each{|v| expect(v.user_id).to eq(seller.id) }

    seller
  end

  def prepare_seller2
    seller2 = find_or_create(:seller_2, :username){|u| u.password = TEST_USER_PASSWORD; }
    seller2.spree_roles << find_or_create(:approved_seller_role, :name) if seller2.spree_roles.count == 0
    seller2.store.store_payment_methods = Spree::PaymentMethod.limit(3).collect do|pm|
      Spree::StorePaymentMethod.new(payment_method_id: pm.id, account_parameters:{ account_id: seller2.email }.to_json )
    end
    sign_in_from_form(seller2)
    seller2
  end

  def prepare_seller3
    seller3 = find_or_create(:seller_3, :username){|u| u.password = TEST_USER_PASSWORD; }
    seller3.store.store_payment_methods = Spree::PaymentMethod.limit(3).collect do|pm|
      Spree::StorePaymentMethod.new(payment_method_id: pm.id, account_parameters:{ account_id: seller3.email }.to_json )
    end
    sign_in_from_form(seller3)
    seller3
  end

  def pick_subset_of_combo_option_value_ids(combos)
    combo_list = combos.shuffle
    combo_option_value_ids = []
    0.upto( [2, combo_list.length].min ).each do|index|
      combo_option_value_ids << combo_list[index]
    end
    combo_option_value_ids
  end

  def check_variant_adoptions(product, seller2, combo_option_value_ids)
    # variant.user_id no longer matters
    variants_adopted = product.variants.joins(:variant_adoption).all
    expect(variants_adopted.size).to eq combo_option_value_ids.size # variants stay same
    variants_adopted.each do|v|
      expect( v.variant_adoptions.all?{|ad| ad.user_id == seller2.id } ).to be_truthy
      if v.user.store.store_payment_methods.size > 0
        expect( v.preferred_variant_adoption ).to be_nil
      end
    end
  end

  def check_product_in_search(product)
    expect(product.indexable?).to be_truthy
    product.es.update_document
    sleep(1) # multiple runs proved update time needed by search index
    search = Spree::Product.es.search(query:{ match:{ '_id': product.id } })
    expect(search.results.total).to eq(1)

    words = product.name.split(/\s+/).collect{|w| w.gsub(/([\W]+)/i, '') }
    visit products_path(keywords: words[0, 2].join(' ') )
    product_card = page.find_all("div[@id='product_#{product.id}']")[0]
    expect(product_card).not_to be_nil
    link = product_card.find_link
    expect(link).not_to be_nil
    expect(link['href'] ).to eq( '/vp/' + product.display_variant_adoption_slug )
  end


end