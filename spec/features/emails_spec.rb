require 'rails_helper'
require 'shared/session_helper'
require 'shared/products_spec_helper'
require 'shared/users_spec_helper'

include SessionHelper
include UsersSpecHelper
include ProductsSpecHelper

RSpec.describe 'Contact User by Email', type: :feature do
  # routes { Spree::Core::Engine.routes }

  before :all do
    setup_all_for_posting_products
    setup_ioffer_categories
    setup_ioffer_payment_methods
  end

  context 'Advertise Email' do
    let :user_attr do
      attributes_for(:basic_user)
    end
    let(:email) { user_attr[:email] }
    let(:username) { user_attr[:username] }
    let(:display_name) { user_attr[:display_name] }

    it 'Organic User' do
      puts '---- Sign up user'
      user = sign_up_with(user_attr[:email], 'test1234', user_attr[:username], user_attr[:display_name] )
      ioffer_user = user.ensure_ioffer_user!
      logout

      puts '--- Reset password email'
      mail = AdvertiserMailer.with(user: user).advertiser_login_list
      text_part = mail.parts.find{|part| part['content-type'].to_s =~ /text\/plain/i }
      expect(text_part).not_to be_nil

      url = text_part.body.match(/\b(https?:\/\/\S+)/ ).try(:[], 1)
      expect(url.present?).to be_truthy
      uri = URI(url)
      url_path = uri.path + '?' + uri.query.to_s

      puts "--- visiting URL in email: #{url_path}"
      visit url_path
      expect(page.current_path).to eq edit_spree_user_password_path

      fill_in 'spree_user[password]', with: 'shop1234'
      fill_in 'spree_user[password_confirmation]', with: 'shop1234'
      click_button 'Update'
      expect(page.current_path).to eq ioffer_brands_path

      select_selling_categories_brands(user)

      select_selling_payment_methods(user)

      expect(page.current_path).to eq '/categories_brands'

    end
  end

end