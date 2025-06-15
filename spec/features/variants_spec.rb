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
  end

  describe 'Create Variant', type: :feature do
    # routes { Spree::Core::Engine.routes }

    let :user_attr do
      attributes_for(:basic_user)
    end
    let :another_user_attr do
      attributes_for(:another_user)
    end
    let(:sample_image_url) { 'http://digg.com/static/images/apple/apple-touch-icon-57.png' }

    context 'Post Variant of Product' do

      it 'Register user and create variant product' do
        puts '---- Sign up user'
        user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )

        puts '---- Confirm email'
        confirm_email(user)

        puts '---- Re-login w/ username'
        sign_in_from_form(user)
        set_user_listing_policy_agreement(user.id)

        price_attr = [{currency: 'USD', amount: 50.0},
          {currency: 'EUR', amount: 48.0}, {currency: 'JPY', amount: 4500.0 } ]
        product_attr = attributes_for(:basic_product)
        product_attr[:user_id] = user.id
        product_attr[:price_attributes] = price_attr
        product = Spree::Product.create(product_attr)
        expect(product.user_id).to eq(user.id)
        variants_count_before = product.original_variants.count
        option_types = product.taxons.first.option_types

        combos = generate_option_value_combos(product.taxons, 
          { option_types.first.id => 2, option_types.last.id => 3 })
        expect(combos.size).to eq( 6 )
        combos.each do|combo|
          product.variants.create(price: product.price, user_id: user.id,
            option_value_variants: Spree::OptionValue.where(id: combo).
              collect{|ov| Spree::OptionValueVariant.new(option_value_id: ov.id) } )
        end
        product.original_variants.reload
        puts "--- Start created some #{variants_count_before + combos.size} variants"
        expect(product.original_variants.count).to eq(variants_count_before + combos.size)

        puts '--- Test use of fill_combos_with_phantom_variants'
        product.fill_combos_with_phantom_variants!
        product.reload
        
        primary_ot = product.option_types.find(&:primary?)
        secondary_ot = product.option_types.find{|ot| !ot.primary? && !ot.brand? }
        primary_ovs = []
        product.original_variants.reload
        product.original_variants.each do|v|
          if primary_ov = v.option_values.find{|_ov| _ov.option_type_id == primary_ot.id }
            primary_ovs << primary_ov
          end
        end
        primary_ovs.uniq!
        # product.variants.each{|v| puts [v.id, v.user_id, v.sku_and_options_text, v.option_values.collect(&:id).sort, '-------------------'] }.class

        secondary_ovs = secondary_ot ? secondary_ot.option_values.to_a : []
        secondary_ovs.reject!(&:one_value?) if secondary_ovs.size > 1 && secondary_ovs.any?(&:one_value?)
        expected_total = variants_count_before + primary_ovs.size * (secondary_ovs.size > 0 ? secondary_ovs.size : 1)
        puts "--- After fill_combos expect total #{expected_total} variants"

        expect(product.sample_variants.where(is_master: false).count).to eq( expected_total )

        puts '--- Test w/ another user trying to access'
        # Check permission against another user
        another_user = sign_up_with(another_user_attr[:email], 'test1234', another_user_attr[:username], another_user_attr[:display_name] )

        another_ability = Spree::Ability.new(another_user)
        expect( another_ability.can?(:manage, product) ).not_to be_truthy

        puts '--- Check permissions'
        ability = Spree::Ability.new(user)
        another_ability = Spree::Ability.new(another_user)
        product.variants.each do|variant|
          expect( ability.can?(:manage, product) ).to be_truthy
          expect( another_ability.can?(:manage, product) ).not_to be_truthy
        end

        puts '--- Another user trying to admin edit the product'
        visit logout_path
        sign_in(another_user)
        page.driver.get spree.edit_admin_product_path(id: product.slug)
        expect(page.response_headers['Location'].index('authorization_failure') ).not_to be_nil

      end # Register user and post variants

      it 'Create Variants from Multiple Sellers' do
        'Create 5 diff seller_rank sellers'
        user_attr = attributes_for(:basic_user)
        users = []
        1.upto(5) do|i|
          rank = (6 - i) * 10
          username = "sellerwith#{rank}"
          user = Spree::User.new(user_attr.merge(username: username, 
            email:"#{username}@gmail.com", seller_rank: rank) 
          )
          user.password = 'test1234'
          user.save
          users << user
        end
        expect( users.all?(&:valid?) ).to be_truthy

        puts 'Sign in w/ 1st seller'
        product = find_or_create(:basic_product, :name) do|p|
          p.user_id = users.first.id
        end
        product.auto_select_rep_variant!
        product.reload
        expect(product.rep_variant_id).to eq product.master.id
=begin
        puts '  Create variants from each seller of descending seller_rank'
        users.sort_by(&:seller_rank).reverse_each do|u|
          v = product.variants.create(user_id: u.id, price:  product.price * [0.8, 0.9, 1.0, 1.2, 1.3].shuffle.first )
          puts "* seller (#{u.id}) w/ #{u.seller_rank} (owner? #{u.id == product.user_id}) => variant #{v.id}"

          product.reload
          puts "  | #{ product.variants_including_master.reload.unscoped.joins(:user).order("seller_rank asc, #{Spree::Variant.table_name}.id DESC").all.collect{|v| [v.is_master, v.id, v.user.seller_rank] } }"
          
          expect(product.rep_variant_id).to eq v.id
        end
=end
      end
    end



  end # describe
end

def check_view_counts(product)

  puts '--- Another user viewing the variant'
  variant_to_view = product.variants_including_master.first
  last_product_view_count = product.view_count
  last_variant_view_count = variant_to_view.view_count
  page.driver.get spree.product_path(id: product.id, t: rand(5000000) )
  product.reload
  variant_to_view.reload
  expect(product.view_count).to eq(last_product_view_count + 1)
  expect(product.view_count).to eq( product.variants_including_master.collect(&:view_count).sum )
  expect(variant_to_view.view_count).to eq(last_variant_view_count + 1)

  puts '--- Revisit variant again'
  last_variant_view_count = variant_to_view.view_count

  page.driver.get spree.variant_path(variant_to_view)
  variant_to_view.reload
  expect(variant_to_view.view_count).to eq(last_variant_view_count)
end