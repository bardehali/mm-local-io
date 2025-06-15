module UsersSpecHelper

  TEST_USER_PASSWORD = 'test1234'

  ##
  # Really depends whether devise initiator is set w/ config
  def required_to_confirm_email?
    !Devise.confirm_within.nil?
  end

  ##
  # iOffer Seller Signup
  def sign_up_with(email, password, username = nil, display_name = nil)
    begin
      visit ioffer_seller_signup_path
      fill_in 'Email', with: email
      fill_in 'user[username]', with: username if username.present?
      # fill_in 'Display Name', with: display_name if display_name
      fill_in 'user[password]', with: password
      fill_in 'user[password_confirmation]', with: password
      click_button 'Submit'

    rescue Exception => e
      raise e unless e.is_a?(::Errno::ECONNREFUSED) # test mail recipient service like mailcatcher not running
      puts "** Ignore exception during registration request: #{e}"
    end
    user = Spree::User.where(email: email).first
    expect(user).not_to be_nil
    expect(user.email).to eq(email)
    if username.present?
      expect(user.username).not_to be_nil
      expect(user.username).to eq(username)
      expect(user.login).to eq(username)
    else
      expect(user.login).to eq(email)
    end
    # expect(user.display_name).not_to be_nil if display_name
    # expect(user.display_name).to eq(display_name)

    expect(user.store).not_to be_nil
    if required_to_confirm_email?
      expect(user.confirmation_token.present?).to be_truthy
      expect(user.confirmed_at).to be_nil
    end

    user_ability = Spree::Ability.new(user)
    expect(user_ability.can?(:create, ::Spree::Product) ).to be_truthy
    user
  end

  ##
  # Sign up, confirm email, and sign in.
  # @return <Spree::User>
  def signup_sample_user(user_factory_key)
    user_attr = attributes_for(user_factory_key)
    user = sign_up_with user_attr[:email], TEST_USER_PASSWORD, user_attr[:username], user_attr[:display_name]
    confirm_email(user) if required_to_confirm_email?

    if user_attr[:spree_roles]
      user.spree_roles = user_attr[:spree_roles]
    end

    sign_in(user)
    user
  end

  ##
  # Sign up from regular create account form
  def signup_buyer(email, password = TEST_USER_PASSWORD)
    begin
      visit signup_path
      expect(page.current_path).to eq signup_path # no redirect to seller form

      fill_in 'Email', with: email
      fill_in 'spree_user[password]', with: password
      fill_in 'spree_user[password_confirmation]', with: password
      click_button 'Sign Up'

    rescue Exception => e
      raise e unless e.is_a?(::Errno::ECONNREFUSED) # test mail recipient service like mailcatcher not running
      puts "** Ignore exception during registration request: #{e}"
    end
    user = Spree::User.where(email: email).first
    expect(user).not_to be_nil
    expect(user.email).to eq(email)
    expect(user.login).to eq(email)

    if required_to_confirm_email?
      expect(user.confirmation_token.present?).to be_truthy
      expect(user.confirmed_at).to be_nil
    end

    expect(user.buyer?).to be_truthy
    expect(user.seller?).to be_falsey

    user
  end

  def sign_in_from_form(user, password = TEST_USER_PASSWORD, which_login_attribute = 'email')
    visit '/logout'
    visit login_path
    expect( page.find_all("//input[placeholder='Email']").size ).not_to eq(0)
    fill_in 'Email', with: (which_login_attribute.to_s == 'email' ? user.email : user.username || user.email)
    fill_in 'Password', with: password || user.password
    click_button 'Log in'
    expect(page).not_to have_content 'Invalid email or password'
  end

  def check_user_abilities(user)
    expect { user.not_to be_nil }
    expect { (user.spree_api_key.present?).to be_truthy }

    # Check abilities
    ability = ::Spree::Ability.new(user)
    puts '---- Check abilities of user'
    if user.seller?
      expect { ability.can?(:new, Spree::Product).to be_truthy }
      expect { ability.can?(:display, Spree::Taxon).to be_truthy }
      [Spree::Product, Spree::ProductOptionType, Spree::ProductProperty].each do|klass|
        expect { ability.can?(:manage, klass).to be_truthy }
      end
    end

    puts '---- Check inabilities of user'
    expect { ability.can?(:destroy, Spree::User).not_to be_truthy }
    expect { ability.can?(:manage, Spree::Role).not_to be_truthy }
  end

  def confirm_email(user)
    if self.respond_to?(:spree_user_confirmation_url)

      confirm_url = spree_user_confirmation_url(confirmation_token: user.confirmation_token)
      begin
        visit confirm_url
        user.reload
      rescue Timeout::Error => user_e
        user.confirmed_at = Time.now
        user.save
      end
      expect(user.confirmed_at).not_to be_nil
    end
  end

  def check_after_sign_in_path(user)
    if user.buyer?
      expect(page.current_path).to eq '/account'
    elsif user.seller?
      expect(page.current_path).to eq '/admin/sales/payment'
    end
  end

  ##
  # @user [Spree::User]
  def select_selling_categories_brands(user)
    puts "  ---- Select categories and brands"
    visit ioffer_brands_path unless current_path == ioffer_brands_path

    selected_taxon_ids = []
    taxon_inputs = page.find_all("input[name='taxon_ids[]']")
    taxon_inputs.each_with_index do|taxon_input, idx|
      next if idx == 0
      check taxon_input['id']
      selected_taxon_ids << taxon_input['value'].to_i
    end
    puts "  on #{page.current_path}, seller? #{user.seller?}, legacy? #{user.legacy?}"
    selected_brand_ids = []
    brand_inputs = page.find_all("input[name='option_value_ids[]']")
    if user.full_seller?
      expect(brand_inputs.size).to be > 0
      brand_inputs.each_with_index do|brand_input, idx|
        next if idx == 0
        check brand_input['id']
        selected_brand_ids << brand_input['value'].to_i
      end

    else
      expect(brand_inputs.size).to eq 0
    end

    click_button (user.full_seller? ? 'Submit Brands' : 'Submit Categories')

    expect( user.user_selling_taxons.reload.collect(&:taxon_id).sort ).to eq selected_taxon_ids.sort
    if selected_brand_ids.size > 0
      expect( user.user_selling_option_values.reload.collect(&:option_value_id).sort ).to eq selected_brand_ids.sort
    end

  end

  ##
  # Ensure DB has payment methods created, such as by setup_all_store_settings.
  def select_store_payment_methods(seller)
    store = seller.fetch_store
    payment_methods_wanted = Spree::PaymentMethod.all.shuffle[0,3]
    unless payment_methods_wanted.find(&:paypal?)
      payment_methods_wanted << Spree::PaymentMethod.paypal
    end
    payment_methods_wanted.each do|pm|
      seller.store.store_payment_methods.find_or_create_by(payment_method_id: pm.id) do|spm|
        spm.attributes = { account_id: seller.email, instruction: "Pay using my account #{seller.login}"}
      end
    end
  end

  ##
  # Basics of effect of user status
  def check_bad_user(user)
    if user.quarantined?
      expect(user.seller_rank).to be <= 0
      Spree::Product.where(user_id: user.id).each do|p|
        expect(p.iqs).to eq(0)
        p.variants_including_master.all? do|v|
          v.seller_based_sort_rank == 0 && v.adoptions.all?{|va| va.seller_based_sort_rank == 0 }
        end
      end
    end
  end

  ##########################################
  # From Spree, api/lib/spree/api/testing_support/helpers.rb
  # where could not simply include module and use

  def stub_authentication_for!(user)
    allow(Spree.user_class).to receive(:find_by).with(hash_including(:spree_api_key)) { user }
  end

  def setup_roles
    %w(admin supplier_admin approved_seller pending_seller hp_seller test_user fake_user phantom_seller quarantined_user).each do|name|
      find_or_create("#{name}_role", :name)
    end
  end

  ##
  # Ioffer::EmailSubscription records
  def setup_subscriptions
    1.upto(5 + rand(5)) do|i|
      sub_user = Spree::User.find_or_create_by(email: "subbuyer0#{i}@gmail.com") do|u|
        u.username = "subbuyer0#{i}"
        u.password = TEST_USER_PASSWORD
      end
      Ioffer::EmailSubscription.create(user_id: sub_user.id, email: sub_user.email,
        captcha_verified: true, ip:'127.0.0.1')
    end
  end

  def setup_phantom_sellers
    attr = attributes_for(:some_phantom_user)
    phantom_seller_role = find_or_create(:phantom_seller_role, :name)
    1.upto(10) do|i|
      user_attr = attr.slice(:email)
      user_attr[:email] = "phantomseller#{i}xoo@gmail.com"
      u = Spree::User.find_or_create_by(email: user_attr[:email] ) do|_u|
        _u.attributes = user_attr
        _u.password = 'test1234'
      end
      u.role_users.find_or_create_by(role_id: phantom_seller_role.id)
    end
    sellers = Spree::User.phantom_sellers.all
    sellers.each do|u|
      expect(u.phantom_seller?).to be_truthy
    end
  end

  def setup_paypal(user)
    user.fetch_store.store_payment_methods.create(
      payment_method_id: find_or_create(:payment_method_paypal, :name).id,
      account_parameters: user.email, instruction: 'Paypal site'
    )
  end

end
