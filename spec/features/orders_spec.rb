require 'rails_helper'
require 'shared/session_helper'
require 'shared/stores_spec_helper'
require 'shared/mailer_spec_helper'
require 'shared/messages_spec_helper'
require 'shared/orders_spec_helper'
require 'shared/products_spec_helper'
require 'shared/users_spec_helper'

include SessionHelper
include StoresSpecHelper
include MessagesSpecHelper
include MailerSpecHelper
include OrdersSpecHelper
include ProductsSpecHelper
include UsersSpecHelper

RSpec.describe ::Spree::Order do
  let(:sample_fixture_file_name) { 'files/color_markers.jpg' }
  let(:sample_image_path) { File.join(ActionDispatch::IntegrationTest.fixture_path,  sample_fixture_file_name) }
  let(:user_attr) {  attributes_for(:basic_user) }

  before(:all) do
    setup_all_store_settings
    setup_all_for_posting_products
    Capybara.ignore_hidden_elements = false
    Capybara.current_driver = :mechanize

    Spree::Config[:track_inventory_levels] = false
    state_ma = find_or_create(:state_ma, :name)
    Spree::Config[:default_country_id] = Spree::Country.first.id
  end

  after(:all) do
    Spree::Order.all.each(&:destroy)
  end

  

  describe 'Order Product' do

    #it 'Guest Buys Phantom Product' do
    #  order = test_signup_guest_and_buy_product # no seller order not invalid to create
    #end

    it 'Guest Buys Seller Product' do
      seller = find_or_create(:seller, :username){|u| u.password = TEST_USER_PASSWORD; }
      order = test_signup_guest_and_buy_product(seller)
    end

    context 'Order no-other-variant via cart, Checkout Sequentially' do

      it 'Orders of Multiple Sellers' do
        puts 'Order of basic products -------------------------------'
        seller = find_or_create(:seller, :username){|u| u.password = TEST_USER_PASSWORD; }
        product = find_or_create(:basic_product, :name) {|p| p.user_id=seller.id; p.available_on = 1.day.ago }
        product2 = find_or_create(:shirt_product, :name) {|p| p.user_id=seller.id; p.available_on = 1.day.ago }
        product3 = find_or_create(:art_craft_product, :name) {|p| p.user_id=seller.id; p.price ||= 30; p.available_on = 1.day.ago }

        seller2 = find_or_create(:seller_2, :username){|u| u.password = TEST_USER_PASSWORD; }
        product4 = find_or_create(:rice_cooker_product, :name) {|p| p.user_id=seller2.id; p.price ||= 59; p.available_on = 1.day.ago }

        buyer = signup_sample_user(:buyer_2)

        puts ' .. 1st seller cart'
        order = add_product_to_cart(buyer, product)
        expect(order).not_to be_nil
        expect(order.user_id).to eq buyer.id
        order_token = order.token
        basic_checks_for_order(order, 'cart')

        order2 = add_product_to_cart(buyer, product2, order_token: order_token)
        expect(order2.id).to eq(order.id)
        basic_checks_for_order(order2, 'cart')

        order3 = add_product_to_cart(buyer, product3, order_token: order_token)
        expect(order3.id).to eq(order.id)
        basic_checks_for_order(order3, 'cart')

        expect(order2.line_items.count).to eq 3
        expect(order3.id).to eq(order2.id)

        remove_product_from_cart(order2, product3)
        order2.reload
        order2.line_items.reload
        expect(order2.line_items.count).to eq 2

        # Problem accessing signed in user is still the obstacle
        proceed_to_checkout(order)
        
        puts ' .. 2nd seller cart'
        order4 = add_product_to_cart(buyer, product4)
        expect(order4).not_to be_nil
        basic_checks_for_order(order4, 'cart')
        remove_product_from_cart(order4, product4)
        order4.reload
        order4.line_items.reload
        expect(order4.line_items.count).to eq 0
      end
    end

    context 'Order no-other-variant via cart, Checkout Together' do

      it 'Succeed with Checkout Together' do
        puts 'Order of no-other-variant -----------------------'
        product = signup_seller_and_post_product
        init_transaction_count = 5
        product.update_columns(transaction_count: init_transaction_count)

        visit logout_path
        buyer = signup_sample_user(:buyer_2)

        order = add_product_to_cart(buyer, product)

        checkout_together(order)

        product.reload
        expect(product.transaction_count).to eq (init_transaction_count + 1)

        new_order_msg = User::NewOrder.find_by(recipient_user_id: product.user_id)
        expect(new_order_msg).not_to be_nil
        expect(new_order_msg.deleted_at).to be_nil

        # manually create seller's response
        seller_msg = User::OrderMessage.create(
          record_type: new_order_msg.record_type, record_id: new_order_msg.record_id, 
          sender_user_id: product.user_id, recipient_user_id: buyer.id,
          parent_message_id: new_order_msg.id
        )

        # manually create buyer's response
        buyer_reply = User::OrderMessage.create(
          record_type: new_order_msg.record_type, record_id: new_order_msg.record_id, 
          sender_user_id: buyer.id, recipient_user_id: product.user_id,
          parent_message_id: seller_msg.id
        )

        old_new_order_msg = User::NewOrder.with_deleted.find_by(recipient_user_id: product.user_id)
        expect(old_new_order_msg).not_to be_nil
        if User::Message::ARCHIVE_PREVIOUS_MESSAGES
          expect(old_new_order_msg.deleted_at).not_to be_nil
        end

        puts " .. onto payment while state=#{order.state}, payment_state=#{order.payment_state}, payment_total: #{order.payment_total}"

        order.update(payment_state: 'paid', payment_total: order.total)
        order.reload
        expect(order.paid?).to be_truthy
        order.messages.reload
        paid_msg = order.messages.last
        expect(paid_msg.is_a?(User::OrderPaymentPaid)).to be_truthy

        order.update(payment_state: 'balance_due')
        order.update(payment_state: 'failed')
        order.reload
        order.messages.reload
        failed_msg = order.messages.last
        expect(failed_msg.is_a?(User::OrderPaymentFailed)).to be_truthy

        order.update(payment_state: 'balance_due', approved_at: Time.now, approver_id: order.seller_user_id)
        order.reload
        order.messages.reload
        confirmed_msg = order.messages.last
        expect(confirmed_msg.is_a?(User::OrderPaymentConfirmed)).to be_truthy

        puts ' .. setup shipments & shipping rates'
        first_shipping_method = Spree::ShippingMethod.first
        tax_rate = find_or_create(:basic_tax_rate, :name)

        order.shipments.each{|sm| sm.shipping_rates.create(shipping_method_id: first_shipping_method.id, cost: 0.0, tax_rate_id: tax_rate.id) }
        order.update(shipment_state: 'shipped')
        order.reload
        order.messages.reload
        shipped_msg = order.messages.last
        expect(shipped_msg.is_a?(User::OrderShipped)).to be_truthy

        # test reviews
        test_review_rating_to_product(buyer, product)
        
        visit logout_path
        buyer2 = signup_sample_user(:buyer_3)
        test_review_rating_to_product(buyer2, product)

      end
    end

    context 'Order product w/ multiple variants via cart' do

      it 'Add to Cart w/ Option Values' do
        product = signup_seller_and_post_product
        populate_variants_for(product)

        visit logout_path
        puts ' .. buyer_2 sign up and Add to Cart w/ options selected'
        buyer = signup_sample_user(:buyer_2)
        last_v = product.variants.first
        more_params = {}
        last_v.option_values.each do|ov|
          more_params["selected_option_value_#{ov.option_type_id}"] = ov.id
        end

        order = add_product_to_cart(buyer, last_v, more_params)
        expect( order.line_items.count).to eq 1
        expect( order.line_items.first.variant_id).to eq last_v.id

        puts ' .. check buyer_2 added LineItem w/ selected options'
        connected_option_value_ids = []
        more_params.each_pair do|k, v|
            if k =~ /\Aselected_option_value/
              if order.line_items.includes(variant: [:option_value_variants]).any? do|line_item|
                included = line_item.variant.option_value_variants.collect(&:option_value_id).include?(v.to_i)
                connected_option_value_ids << v.to_i if included
                included
              end
            end
          end
        end
        expect(connected_option_value_ids.sort).to eq last_v.option_values.collect(&:id)

        checkout_together(order)
      end
    end

    context 'Order product w/ multiple variants w/ variant adoptions' do

      it 'Order variant adoption instead of variant' do
        puts 'Order w/ variant adoptions ----------------------------------------'
        product = signup_seller_and_post_product(:some_phantom_user)

        expect(product.user.seller?).to be_truthy
        expect(product.user.phantom_seller?).to be_truthy

        visit logout_path

        seller_2 = signup_sample_user(:another_seller)
        select_store_payment_methods(seller_2)

        seller_2_variant_price = product.price * 0.9
        combo_option_value_strings = product.variants.includes(:option_value_variants).to_a.shuffle[0,10].collect{|v| v.option_value_variants.collect{|ovv| ovv.option_value_id.to_s }.join(',') }
        post admin_list_variants_path(id: product.id, product:{variant_price: seller_2_variant_price }, 
          combo_option_value_ids: combo_option_value_strings )
        seller_2_adoptions_q = Spree::VariantAdoption.where(user_id: seller_2.id)
        adoption_count = seller_2_adoptions_q.count
        expect(adoption_count).to eq combo_option_value_strings.size
        expect( seller_2_adoptions_q.all.all?{|ad| ad.price == seller_2_variant_price } ).to be_truthy
        puts " .. Seller 2 adopted #{ adoption_count }"

        visit logout_path

        puts ' .. buyer_2 sign up and Add to Cart w/ options selected'
        buyer = signup_sample_user(:buyer_2)
        last_v = product.variants.includes(:variant_adoptions).find{|v| v.variant_adoptions.size > 0 }
        the_variant_adoption = last_v.variant_adoptions.first
        more_params = {}
        last_v.option_values.each do|ov|
          more_params["selected_option_value_#{ov.option_type_id}"] = ov.id
        end
        more_params[:variant_adoption_id] = the_variant_adoption.id

        order = add_product_to_cart(buyer, the_variant_adoption, more_params)
        expect( order.seller_user_id ).to eq the_variant_adoption.user_id
        expect( order.store_id ).to eq the_variant_adoption.user.store.id
        expect( order.line_items.count).to eq 1
        expect( order.line_items.first.variant_id).to eq last_v.id
        expect( order.line_items.first.variant_adoption_id).to eq the_variant_adoption.id
        expect( order.line_items.first.price).to eq the_variant_adoption.price
        expect( order.confirmation_delivered).not_to be_truthy

        puts ' .. check buyer_2 added LineItem w/ selected options'
        connected_option_value_ids = []
        more_params.each_pair do|k, v|
            if k =~ /\Aselected_option_value/
              if order.line_items.includes(variant: [:option_value_variants]).any? do|line_item|
                included = line_item.variant.option_value_variants.collect(&:option_value_id).include?(v.to_i)
                connected_option_value_ids << v.to_i if included
                included
              end
            end
          end
        end
        expect(connected_option_value_ids.sort).to eq last_v.option_values.collect(&:id)

        checkout_together(order)
      end
    end

    context 'Order product w/ multiple variants of multiple sellers' do

      it 'Add to Cart w/ Option Values' do
        product = signup_seller_and_post_product
        seller1 = product.user
        store1 = seller1.fetch_store
        populate_variants_for(product)

        puts 'Seller 2 signup and copy variants --------------'
        visit logout_path
        seller2_attr = attributes_for(:seller_2)
        seller2 = sign_up_with(seller2_attr[:email], TEST_USER_PASSWORD, seller2_attr[:username] )
        store2 = seller2.fetch_store
        
        Spree::PaymentMethod.all.each do|pm|
          store1.store_payment_methods.find_or_create_by(payment_method_id: pm.id)
          store2.store_payment_methods.find_or_create_by(payment_method_id: pm.id)
        end

        old_variants_count = product.variants.count
        product.variants.to_a.each do|v|
          v2 = product.variants.create( v.attributes.except('id').merge(user_id: seller2.id, price: v.price * 0.9) )
          v.option_value_variants.each{|ovv| v2.option_value_variants.create(option_value_id: ovv.option_value_id) }
        end
        product.reload
        product.variants.reload
        expect( product.variants.find{|v| v.user_id == seller2.id } ).not_to be_nil
        expect( product.variants.count ).to eq old_variants_count * 2

        best_v = product.variants_including_master.includes(user: [:role_users => [:role] ] ).to_a.reject{|v| v.seller_based_sort_rank.to_i.zero? }.sort_by(&:price).first
        expect(product.best_variant_id).to eq(best_v.id) if product.retail_site_id.to_i > 0 || product.user&.phantom_seller?

        visit logout_path
        puts ' .. buyer_2 sign up and Add to Cart w/ options selected'
        buyer = signup_sample_user(:buyer_2)
        buyer.addresses << Spree::Address.new( attributes_for(:basic_address) )
        
        last_v = product.variants.find{|v| v.option_value_variants.count > 0 && v.user_id == seller1.id }
        more_params = { quantity: 1 }
        last_v.option_values.each do|ov|
          more_params["variant_option_value_id_#{ov.option_type_id}"] = ov.id
        end

        puts " .. Adding seller 1 variant #{last_v.id} to cart"
        order = process_add_to_cart_via_json(buyer, last_v, more_params)
        expect(order).not_to be_nil
        expect(order.store_id).to eq seller1.fetch_store.id
        expect( order.line_items.count).to eq 1
        expect( order.line_items.first.variant_id).to eq last_v.id
        expect( order.line_items.first.product_id).to eq last_v.product_id
        expect( order.line_items.first.quantity).to eq 1

        puts " .. Try confirming the selection of seller 1 variant #{last_v.id} to cart"
        store1_payment_method_id = store1.store_payment_methods.first.payment_method_id
        order = process_add_to_cart_via_json(buyer, last_v, more_params.merge(payment_method_id: store1_payment_method_id) )
        expect(order).not_to be_nil
        expect( order.line_items.count).to eq 1
        expect( order.line_items.first.variant_id).to eq last_v.id
        expect( order.line_items.first.product_id).to eq last_v.product_id
        expect( order.line_items.first.quantity).to eq 1
        expect( order.payments.find{|payment| payment.payment_method_id == store1_payment_method_id }).not_to be_nil

        puts 'Same Option Values But Different seller --------------------'
        another_v = product.variants.find{|v| v.user_id != last_v.user_id && v.option_value_variants.collect(&:option_value_id) == last_v.option_value_variants.collect(&:option_value_id) }
        expect(another_v).not_to be_nil
        expect(another_v.user_id).not_to eq last_v.user_id

        store2_payment_method_id = store2.store_payment_methods.last.payment_method_id 
        more_params = { payment_method_id: store2_payment_method_id }
        another_v.option_values.each do|ov|
          more_params["variant_option_value_id_#{ov.option_type_id}"] = ov.id
        end

        puts " .. Adding seller 2 variant #{another_v.id} to cart"
        order2 = process_add_to_cart_via_json(buyer, another_v, more_params)
        expect(order2).not_to be_nil
        expect( order2.id ).not_to eq order.id
        expect(order2.store_id).to eq seller2.fetch_store.id
        expect( order2.line_items.count).to eq 1
        expect( order2.line_items.first.variant_id).to eq another_v.id
        expect( order2.payments.find{|payment| payment.payment_method_id == store2_payment_method_id }).not_to be_nil

        order.line_items.reload
        expect( order.line_items.size).to eq 0

        puts 'Same 2nd Seller But Different Option Values --------------------'
        third_v = product.variants.find{|v| v.user_id == another_v.user_id && v.option_value_variants.collect(&:option_value_id) != another_v.option_value_variants.collect(&:option_value_id) }
        expect(third_v).not_to be_nil

        more_params = {}
        third_v.option_values.each do|ov|
          more_params["variant_option_value_id_#{ov.option_type_id}"] = ov.id
        end
        order_of_third_v = process_add_to_cart_via_json(buyer, third_v, more_params)
        expect(order_of_third_v&.id).to eq order2.id
        expect(order_of_third_v.line_items.collect(&:variant_id).sort ).to eq [another_v.id, third_v.id].sort

        puts "  Move onto next state #{order2.state} of order2"
        visit checkout_state_path(order2.state)
        address_radio = page.all("input[type='radio']").find{|e| e['value'].to_i > 0 }
        expect(address_radio).not_to be_nil
        page.choose address_radio['id']

        submit_button = page.all("div[data-hook='buttons']//button").last
        submit_button.click

        order2.reload
        if Spree::Order::AUTO_SELECT_SHIPPING_METHOD
          if order2.payments.any?
            expect(order2.state).to eq 'complete'
          else
            expect(order2.state).to eq 'payment'
          end
        else
          if order2.payments.any?
            expect(order2.state).to eq 'complete'
          else
            expect(order2.state).to eq 'address'
          end
        end
        expect(order2.ship_address_id).to eq buyer.addresses.first.id

        # Still mysterious how test level does not get enough shipping settings to make shipping rates 
        if order2.shipments.blank?
          order2.create_proposed_shipments.each do|shipment|
            Spree::ShippingMethod.all.each_with_index do|sm, index|
              shipment.shipping_rates.create(shipping_method_id: sm.id, cost: 0, selected: index.zero?)

            end
          end
        end

      end
    end

  end # describe
end
