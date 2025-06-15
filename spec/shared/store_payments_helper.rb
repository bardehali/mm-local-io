module StorePaymentsHelper
  # Main steps of source country seller registration
  def source_country_steps(user)

    wechat = Spree::PaymentMethod.wechat
    paypal = Spree::PaymentMethod.paypal

    if user.legacy?
      puts 'Legacy User -------------------------'
      puts '  ---- Brands for legacy'
      expect(page.current_path).to eq ioffer_brands_path

      select_selling_categories_brands(user)

      check_after_categories_brands_page(user)

    elsif Spree::User::UNACCEPTED_COUNTRIES_FOR_BUYER.include?(user.country.downcase)
      expect(page.current_path).to eq '/payments'
      puts "Unaccepted country #{user.country} -------------------------"

    elsif Spree::User::ACCEPTED_COUNTRIES_FOR_FULL_SELLER.include?(user.country.downcase)
      puts "Accepted country for full seller #{user.country} ------------------------"
      puts '  ---- Set contact info'
      expect(page.current_path).to eq '/seller_contact_info'

      second_email = user.username + '@yahoo.com'
      set_seller_contact_info(user, user.username, second_email)
  
      puts '  ---- Payment options'
      expect(page.current_path).to eq '/payment_options'

      paypal_input = page.find("input[name='payment_method_account_ids[#{paypal.id}]']")
      expect(paypal_input).not_to be_nil
      paypal_input.set(user.email)
      click_button 'Submit'
  
      user.reload
      expect(user.store).not_to be_nil
      expect(user.store.has_payment_method?(paypal.id) ).to be_truthy

      puts '  ---- Payment methods provided'
      expect(page.current_path).to eq payment_methods_provided_path
      selected_pms = select_selling_payment_methods(user)

      puts '  ---- Payment accounts'
      expect(page.current_path).to eq '/payment_method_accounts'
      
      requires_instruction = ControllerHelpers::SellerManager::REQUIRES_INSTRUCTION
      user.store.store_payment_methods.reload
      selected_pms.each do|pm|
        pm_account_id = page.find("input[name='payment_method_account_ids[#{pm.id}]']")
        expect(pm_account_id).not_to be_nil
        pm_account_id.set(user.email)

        if requires_instruction
          pm_instruction = page.find("input[name='payment_method_instruction[#{pm.id}]']")
          pm_instruction.set("Pay with #{pm.name}")
        end
      end
      click_button 'Submit'

      user.store.store_payment_methods.reload
      selected_pms.each do|selected_pm|
        found_spm = user.store.store_payment_methods.find{|spm| spm.payment_method_id == selected_pm.id }
        expect(found_spm).not_to be_nil
        expect(found_spm.account_id_in_parameters).to eq user.email
        if requires_instruction
          expect(found_spm.account_hash['instruction']).to eq "Pay with #{selected_pm.payment_method.name}"
        end
      end
    end

  end

  ##########################################
  # Database
  def setup_payment_methods
    # [:payment_method_paypal, :payment_method_wechat, :payment_method_credit_card].each{|k| find_or_create(k, :name) }
    Spree::PaymentMethod.clear_cache
    Spree::PaymentMethod.populate_with_common_payment_methods
  end

  ###################################
  # Partial methods

  protected

  ##
  # iOffer Landing checks
  # Switched to show and select Spree::PaymentMethod
  # @return [Array of Spree::PaymentMethod] selected
  def select_selling_payment_methods(user)

    puts '  ---- Select payment methods'
    visit payment_methods_provided_path unless current_path == payment_methods_provided_path

    # These requested in list on /payments page
    ideal_payment_methods = ['paypal', 'transferwise', 'alipay', 'wechat', 'worldpay', 'ipaylinks', 'western_union', 'bitcoin', 'paysend', 'scoinpay', 'ping']

    selected_payment_methods = []
    selected_payment_method_ids = []
    idx = 0
    Spree::PaymentMethod.where(name: ideal_payment_methods).each do|pm|
      pm_input = page.find_all("input[name='payment_method_ids[]'][value='#{pm.id}']").find{|input| input['value'] == pm.id.to_s }
      expect(pm_input).not_to be_nil
      if idx % 2 == 1
        selected_payment_method_ids << pm.id
        selected_payment_methods << pm
        pm_input.set(true)
      end
      idx += 1
    end
    if selected_payment_methods.size > 0
      click_button 'Submit'
    end
    store_pms = user.fetch_store.store_payment_methods.reload
    selected_payment_method_ids.each do|_id|
      store_pms.collect(&:id).include?(_id)
    end

    selected_payment_methods
  end

  ##
  # Of current user, check to select to Connect to PayPal and add other payment methods.
  def check_payment_methods(user)
    ::Spree::PaymentMethod.populate_with_common_payment_methods
    paypal = ::Spree::PaymentMethod.paypal
    expect(paypal).not_to be_nil
    paypal_account = 'somepaypalaccount@gmail.com'
    post admin_payment_methods_and_retail_stores_path(payment_method_account_ids:{ paypal.id => paypal_account } )

    paypal_spm = user.store.store_payment_methods.where(payment_method_id: paypal.id).first
    expect(paypal_spm).not_to be_nil
    expect(paypal_spm.account_id_in_parameters).to eq paypal_account

    another_payment_method = ::Spree::PaymentMethod.last
    if another_payment_method && another_payment_method.id != paypal.id
      post admin_payment_methods_and_retail_stores_path(payment_method_account_ids:{ another_payment_method.id => 'morepayment@gmail.com' }  )

      user.store.payment_methods.reload
      expect(user.store.payment_methods.where(name: another_payment_method.name).first ).not_to be_nil
    end

    puts '---- Check store_payment_methods'
    visit admin_store_payment_methods_path
    user.store.store_payment_methods.includes(:payment_method).each do|spm|
      payment_input_id = "payment_method_account_ids[#{spm.payment_method_id}]"
      payment_input = page.find("input[name='#{payment_input_id}']")
      expect(payment_input['value'] ).to eq spm.account_id_in_parameters
      if spm.instruction.present?
        expect(payment_input["payment_method_instruction[#{spm.payment_method_id}]"] ).to eq spm.instruction
      end
    end
  end

  ##
  # Expect current page to be /seller_contact_info
  def set_seller_contact_info(user, wechat_account = '', secondary_email = nil)
    wechat = Spree::PaymentMethod.wechat
    user.fetch_store.store_payment_methods.delete_all

    page.find_all("input[name='other_site_accounts[wechat]']").find{|input| input.set(wechat_account) }
    
    secondary_email_input = page.find_all("input[name='user[secondary_email]']").first
    expect(secondary_email_input).not_to be_nil

    secondary_email_input.set(secondary_email)
    click_button 'Submit'

    user.reload
    if wechat_account.present?
      saved_account_id = user.other_site_accounts.where(site_name:'wechat').first&.account_id
      expect(saved_account_id).to eq wechat_account

      # Previous version had wechat as StorePaymentMethod
      user.reload
      expect( user.store.has_payment_method?(wechat.id) ).not_to be_truthy
    end
    if secondary_email.present?
      expect(user.secondary_email).to eq(secondary_email)
    end
  end

end