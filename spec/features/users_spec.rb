require 'rails_helper'
require 'shared/session_helper'
require 'shared/products_spec_helper'
require 'shared/users_spec_helper'
require 'shared/store_payments_helper'
require 'shared/mailer_spec_helper'

include SessionHelper
include UsersSpecHelper
include ProductsSpecHelper
include StorePaymentsHelper
include ControllerHelpers::GeoFence
include MailerSpecHelper

RSpec.describe 'Register a user', type: :feature do
  # routes { Spree::Core::Engine.routes }

  before :all do
    setup_category_taxons( [:level_one_category_taxon, :level_two_category_taxon, :level_three_category_taxon] )
    setup_option_types_and_values
    setup_ioffer_categories
    setup_ioffer_brands
    setup_payment_methods
    find_or_create(:ioffer, :name)
    ENV['REQUEST_IP'] = '127.0.0.1'
  end

  context 'Registering user' do
    let :user_attr do
      attributes_for(:basic_user)
    end
    let(:email) { user_attr[:email] }
    let(:username) { user_attr[:username] }
    let(:display_name) { user_attr[:display_name] }
    let(:user) { nil }


    it 'Sign up buyer' do
      puts 'Sign up buyer -------------'
      user = signup_buyer(user_attr[:email], 'test1234')
      
      check_after_sign_in_path(user)

      puts '---- Set info by IP'
      set_user_country_by_ip(user)
      user.reload

      expect(user.buyer?).to be_truthy
      expect(user.seller?).not_to be_truthy
      
      check_user_abilities(user)

      puts '---- Confirm email'
      confirm_email(user)

      puts '---- Relogin w/ username'
      visit logout_path
      sign_in_from_form(user)
      check_after_sign_in_path(user)

      puts '---- Relogin w/ email'
      visit logout_path
      sign_in_from_form(user, 'test1234', 'email')

      [admin_products_path, '/admin/', '/admin/orders'].each do|p|
        visit p
        expect(page.current_path).not_to eq p
      end

    end # buyer

    it 'Sign up pending/non-full seller' do
      puts 'Sign up pending seller --------------'
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )

      country = Spree::User::UNACCEPTED_COUNTRIES_FOR_BUYER.shuffle.first
      puts "---- set country to #{country}"
      user.update(country: country, last_sign_in_ip: ENV['REQUEST_IP'] )
      visit '/next_after_save'

      expect(page.current_path).to eq ioffer_payments_path

      puts '---- Set info by IP'
      set_user_country_by_ip(user)
      user.reload

      expect(user.seller?).to be_truthy
      expect(user.approved_seller?).not_to be_truthy

      check_user_abilities(user)

      source_country_steps(user)

      puts '---- Confirm email'
      confirm_email(user)

      puts '---- Relogin w/ username'
      visit logout_path
      sign_in_from_form(user)

      puts '---- Relogin w/ email'
      visit logout_path
      sign_in_from_form(user, 'test1234', 'email')
      
      expect(page.current_path).to eq admin_products_path

      expect(user.store).not_to be_nil
      visit '/'
      if user.store.payment_methods.count == 0
        # expect(current_url.ends_with?(spree_store_payment_methods_path) ).to be_truthy
        check_payment_methods(user)
      end

      [admin_products_path].each do|p|
        visit p
        expect(page.current_path).to eq p
      end

      puts '---- Sign up 2nd seller'
      visit logout_path
      seller2 = sign_up_with("second" + user_attr[:email], 'test1234', "second" + user_attr[:username], user_attr[:display_name] )
      seller2.update(country: country, last_sign_in_ip: ENV['REQUEST_IP'] )
      
      puts '    --- Try to use same Payment method account'
      paypal = ::Spree::PaymentMethod.paypal
      paypal_account = user.store.store_payment_methods.where(payment_method_id: paypal.id).first&.account_id_in_parameters
      post admin_payment_methods_and_retail_stores_path(payment_method_account_ids:{ paypal.id => paypal_account } )
      seller2.reload
      second_paypal_spm = seller2.store.store_payment_methods.where(payment_method_id: paypal.id).first
      expect(second_paypal_spm).to be_nil

    end # non-full-seller

    it 'Sign up accepted source country full seller' do
      puts 'Sign up accepted source country full seller --------------'
      user_attr = attributes_for(:basic_user, :china_email)
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )
      expect( Spree::User.where(username: user_attr[:username]).count ).to eq(1)

      expect(user.country).to eq 'china'
      expect(user.seller?).to be_truthy
      expect(user.full_seller?).to be_truthy

      # china email alone is good enough
      mail = if is_delivery_method_test?
          ActionMailer::Base.deliveries.find do|m|
            m.to.collect(&:to_s).include?(user.email)
          end
        else
          user.send_confirmation_instructions(Spree::Store.current)
        end
      expect(mail).not_to be_nil
      check_mail_settings(user, mail, 'aliyun')
      
      visit '/next_after_save'

      source_country_steps(user)

      puts '  ------------ double check same username overtake by another seller'
      visit '/logout'
      another_user_attr = attributes_for(:basic_user, :china_email)
      another_user_attr[:email] = 'more' + another_user_attr[:email]
      another_user = sign_up_with(user_attr[:email], 'test1234asdf', user_attr[:username], user_attr[:display_name] )
      
      check_another_user = Spree::User.where(email: another_user_attr[:email]).last
      expect(check_another_user).to be_nil

      check_first_user = Spree::User.where(username: user_attr[:username] ).first
      expect(check_first_user.email).to eq( user_attr[:email] )
      expect( Spree::User.where(username: user_attr[:username]).count ).to eq(1)

    end

    it 'Sign up from Japan unaccepted full-seller country but accepted buyer country' do
      puts 'Sign up fom Japan --------------'
      user_attr = attributes_for(:basic_user, :ip_japan)
      ENV['REQUEST_IP'] = user_attr[:current_sign_in_ip]
      ENV['REQUEST_COUNTRY'] = 'Japan'
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )
      user.update(country: 'Japan')
      @spree_current_user = user

      expect(user.country).to eq 'Japan'
      expect(user.seller?).to be_truthy
      expect(user.full_seller?).not_to be_truthy

      expect( accepted_location? ).to be_truthy
      accepted_buyer = Spree::User::UNACCEPTED_COUNTRIES_FOR_BUYER.exclude?(user.country.downcase)
      expect( accepted_location_for_buyer? ).to eq accepted_buyer
      expect( can_pass_geofence? ).to be_truthy

      mail = user.send_confirmation_instructions(Spree::Store.current)
      check_mail_settings(user, mail, 'gmail')
    end

    it 'Sign up from France unaccepted full-seller country and unaccepted buyer country' do
      puts 'Sign up fom France --------------'
      user_attr = attributes_for(:basic_user, :ip_france)
      ENV['REQUEST_IP'] = user_attr[:current_sign_in_ip]
      ENV['REQUEST_COUNTRY'] = 'France'
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )
      user.update(country: 'France')
      @spree_current_user = user

      expect(user.country).to eq 'France'
      expect(user.full_seller?).not_to be_truthy
      expect(user.buyer?).not_to be_truthy

      expect( accepted_location? ).not_to be_truthy
      accepted_buyer = Spree::User::UNACCEPTED_COUNTRIES_FOR_BUYER.exclude?(user.country.downcase)
      expect( accepted_location_for_buyer? ).to eq accepted_buyer
      expect( can_pass_geofence? ).not_to be_truthy

      mail = user.send_confirmation_instructions(Spree::Store.current)
      check_mail_settings(user, mail, 'gmail')

      puts '  ---- Populate products'
      products = populate_products_for_user(user)

      other_product = find_or_create(:shirt_product, :name)
      expect(other_product.user_id).not_to eq user.id
      user_variant = other_product.variants.create(user_id: user.id, price: other_product.master.price + 2.0)
      expect(user_variant.user_id).to eq user.id

      puts "  ---- Test destroying user w/ #{products.size} products"
      user.destroy

      user_again = Spree::User.with_deleted.where(id: user.id).first
      expect(user_again).not_to be_nil
      expect(user_again.deleted_at).to be_nil
      expect(user_again.seller_rank).to be <= 0
      # Products r no longer just destroyed
      expect( Spree::Product.where(user_id: user.id).search_indexable.count ).to eq 0
      expect( Spree::Variant.where(product_id: other_product.id, user_id: user.id).count ).to eq 1
      expect( Spree::Variant.where(user_id: user.id).all.none?(&:available?) ).to be_truthy
    end


    it 'Register Full Seller' do
      puts 'Sign up full seller using cheating environment variables --------------------------'
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )

      address = create(:full_seller_address)
      user.country = address.country
      user.save
      user.reload
      ENV['REQUEST_IP'] = '127.0.0.1'
      ENV['REQUEST_COUNTRY'] = user.country
      
      expect(user.full_seller?).to be_truthy
      expect( source_country?('127.0.0.1') ).to be_truthy

      visit '/next_after_save'
      source_country_steps(user)
      
      # select_selling_payment_methods(user)


      select_selling_categories_brands(user)

      check_after_categories_brands_page(user)

      [admin_products_path, admin_fill_your_shop_path].each do|p|
        visit p
        expect(page.current_path).to eq p
      end

      # legacy seller only
      if user.legacy?
        ['/admin/orders', admin_products_adopted_path].each do|p|
          visit p
          expect(page.current_path).to eq p
        end
      end
  
    end
  end

  context 'Check against user such as stats' do
    let :user_attr do
      attributes_for(:basic_user)
    end
    
    it 'User recaculate_user_stats' do
      user = sign_up_with('justsomeguy@gmail.com', 'test1234', 'someguy')

      common_product_attr = { price: 30, taxon_ids: [Spree::Taxon.last.id], 
        shipping_category: Spree::ShippingCategory.default}
      product1 = Spree::Product.create(
        common_product_attr.merge(user_id: user.id, name:'Fucking good sneakers in black', 
          description:'More to say asshole. Contact me via user@gmail.com') )
      product2 = Spree::Product.create(
        common_product_attr.merge(user_id: user.id, name:'Blue Hoodie in shit Good STyle', 
        description:'More to say. Send to whoever@wherever.com') )
      
      stats = user.recalculate_user_stats!
      puts " .. Those products got stats: #{stats}"
      expect(stats[Spree::User::COUNT_OF_CONTACT_INFO_INFRINGEMENTS] ).to eq 3
      expect(stats[Spree::User::COUNT_OF_BAD_BANNED_WORDS] ).to eq 3
    end

    it 'Soft Delete User' do
      puts 'Soft Delete User'
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )

      address = create(:full_seller_address)
      user.country = address.country
      user.save
      user.reload
      ENV['REQUEST_IP'] = '127.0.0.1'
      ENV['REQUEST_COUNTRY'] = user.country
      
      expect(user.full_seller?).to be_truthy
  
    end
  end

  protected

  def check_after_categories_brands_page(user)
    if user.full_seller? || user.approved_seller?
      expect(page.current_path).to eq admin_wanted_products_path
    elsif user.seller?
      expect(page.current_path.starts_with?('/admin/products') ).not_to be_nil
    else
      expect(page.current_path).to eq '/payments'
    end
  end

  def set_user_country_by_ip(user)
    ip_user = build(:seller, :real_ip)
    begin
      # Test whether GeoIp service is working
      user.current_sign_in_ip = ip_user.current_sign_in_ip
      user.save
    rescue Timeout::Error => api_e
      user.current_sign_in_ip = nil
      sample_address = create(:sample_address)
      user.country = sample_address.country
      user.save
    end
  end

  ##
  # For GeoFence
  def spree_current_user
    @spree_current_user
  end

  ##
  # For GeoFence
  def session
    @session ||= {}
  end

  def logger
    Spree::User.logger
  end
end