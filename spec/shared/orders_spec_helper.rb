module OrdersSpecHelper
  def self.included(base)
    base.include MailerSpecHelper if base.included_modules.exclude?(MailerSpecHelper)
    base.include MessagesSpecHelper if base.included_modules.exclude?(MessagesSpecHelper)
    base.include Spree::MorePaymentsHelper if base.included_modules.exclude?(Spree::MorePaymentsHelper)
  end

  def basic_checks_for_order(order, expected_state = nil)
    buyer_a = Spree::Ability.new(order.buyer)
    seller_a = Spree::Ability.new(order.seller)

    expect( buyer_a.can?(:show, order) ).to be_truthy
    expect( buyer_a.can?(:edit, order) ).to be_truthy
    expect( buyer_a.can?(:update, order) ).to be_truthy
    
    expect( seller_a.can?(:update, order) ).to be_truthy
    expect( seller_a.can?(:delete, order) ).to be_falsey


    buyer3 = find_or_create(:buyer_3, :username){|u| u.password = 'test1234'; }
    buyer3_a = Spree::Ability.new(buyer3)
    expect( buyer3_a.can?(:show, order) ).to be_falsey
    expect( buyer3_a.can?(:update, order) ).to be_falsey

    if expected_state
      expect(order.state).to eq expected_state
    end
  end

  ##
  # Queries UI elements and sends request, using @process_add_to_cart
  # Changed the style of tests: from HTML elements interactions to manual making of requests.
  # @return <Spree::Order> The order in cart state
  def add_product_to_cart(user, product_or_variant, more_params = {})
    order = nil
    puts "    .. #{user ? user.id : 'guest'} adding #{product_or_variant.class.to_s} #{product_or_variant.id} to cart"
    load_product_or_variant(product_or_variant) do|product, variant|
      # post populate_orders_path( more_params.merge(format:'json', variant_id: variant.id, quantity: 1) )

      # This depends on default_variant, but error occurs if called product.default_variant
      # variant_id_value = page.find("//input[id='variant_id']").value
      # expect(variant_id_value.to_i).to eq(variant.id)
      
      order = process_add_to_cart_via_js(user, variant, more_params)
    end
    order
  end


  ##
  # Sends AJAX request to add to cart.  Expect order.user_id and order.seller_user_id for checking.
  # @variant_or_adoption [Spree::Variant or Spree::VariantAdoption]
  def process_add_to_cart_via_js(user, variant_or_adoption, more_params)
    variant = variant_or_adoption.is_a?(Spree::Variant) ? variant_or_adoption : variant_or_adoption.variant
    adoption = variant_or_adoption.is_a?(Spree::VariantAdoption) ? variant_or_adoption : nil
    expected_seller_user_id = adoption ? adoption.user_id : variant.user_id
    post populate_orders_path(
      { format:'js', variant_id: variant.id, variant_adoption_id: adoption&.id, quantity: 1 }.merge(more_params) )

    order_cond = { state:'cart', seller_user_id: expected_seller_user_id }
    test_after_add_to_cart(user, variant_or_adoption, order_cond)
  end


  ##
  # Sends request add to cart, and could fix problem like test session signed in user ID.
  def process_add_to_cart_via_json(user, variant_or_adoption, more_params)
    variant = variant_or_adoption.is_a?(Spree::Variant) ? variant_or_adoption : variant_or_adoption.variant
    adoption = variant_or_adoption.is_a?(Spree::VariantAdoption) ? variant_or_adoption : nil
    expected_seller_user_id = adoption ? adoption.user_id : variant.user_id
    post add_item_api_v2_storefront_cart_path(
      { format:'json', variant_id: variant.id, quantity: 1 }.merge(more_params) )
    cart_data = JSON.parse(page.body)
    cart_data = cart_data['data'] if cart_data.keys == %w(data)
    order_token = cart_data['attributes']['token']

    order_cond = { state:'cart', token: order_token }
    test_after_add_to_cart(user, variant_or_adoption, order_cond)
  end

  # Common helper method used by process_add_to_cart_*
  # @variant_or_adoption [Spree::Variant or Spree::VariantAdoption]
  def test_after_add_to_cart(user, variant_or_adoption, query_order_cond)
    variant = variant_or_adoption.is_a?(Spree::Variant) ? variant_or_adoption : variant_or_adoption.variant
    adoption = variant_or_adoption.is_a?(Spree::VariantAdoption) ? variant_or_adoption : nil
    order = Spree::Order.incomplete.where(query_order_cond).last

    expect(order).not_to be_nil
    
    # Test session has problem providing signed in user, the buyer reference in order
    if order.user_id.nil? && user.try(:id)
      order.user_id = user.id
      order.save
      order.create_message!

      check_message_for(order, order.user_id, order.seller_user_id) do|msg|
        expect(msg.class).to eq User::NewOrder
      end
    end

    line_item_cond = { variant_id: variant.id }
    line_item_cond[:variant_adoption_id] = adoption.id if adoption
    line_item = order.line_items.where(line_item_cond).last
    expect(line_item).not_to be_nil
    order
  end

  def remove_product_from_cart(order, product_or_variant)
    found_line_item = order.line_items.find do|line_item|
      product_or_variant.is_a?(::Spree::Product) ?
        (product_or_variant.id == line_item.product_id) :
        (product_or_variant.id == line_item.variant_id)
    end
    expect(found_line_item).not_to be_nil
    line_items_h = {}
    order.line_items.each_with_index do|line_item, idx|
      line_items_h[idx.to_s] = { id: line_item.id, quantity: 
        found_line_item.id == line_item.id ? 0 : line_item.quantity }
    end
    put order_path(order, order:{ line_items_attributes: line_items_h })
    order.reload
    order
  end

  ##
  # Helper method used by add_product_to_cart and remove_product_from_cart
  # @product_or_variant [Spree::Product or Spree::Variant or Spree::VariantAdoption]
  def load_product_or_variant(product_or_variant, &block)
    variant = product_or_variant.is_a?(::Spree::Product) ? product_or_variant.master : 
      (product_or_variant.is_a?(Spree::VariantAdoption) ? product_or_variant.variant : product_or_variant)
    product = variant.product
    if variant.is_a?(::Spree::Variant) && respond_to?(:variant_path)
      visit variant_path(id: variant.id)

    else

      visit product_path(id: product.id)
      # handle selecting variant and Add to Cart
    end
    if block_given?
      yield product, (product_or_variant.is_a?(Spree::VariantAdoption) ? product_or_variant : variant )
    end
  end


  def prepare_address_attributes(address)
    address_attr = {}
    [:firstname, :lastname, :address1, :address2, :city, :state_id, :zipcode, :country_id, :phone, :id].each{|a| address_attr[a] = address.send(a) }
    address_attr
  end

  def submit_billing_address(order, address)
    patch update_checkout_path(
              state: 'address', order_id: order.id, save_user_address: true,
              order: { email: order.user.email,
                       bill_address_attributes: prepare_address_attributes(address),
                       use_billing: true } )
  end

  def proceed_to_checkout(order)
    visit cart_path(token: order.token)
    checkout_url = nil
    find_all(:xpath, "//a[text()='checkout']").each do|n|
      if n[:href].include?("id=#{order.id}") || n[:href].include?("token=#{order.number}")
        checkout_url = n[:href]
      end
    end
    expect(checkout_url).not_to be_nil

    visit checkout_url
    if can_process_all_states?(order)

      puts ' .. checking combined order '
      expect(page).to have_content( Spree.t('save_and_continue') )

      unless order.payments.any?
        expected_pm_ids = order.available_payment_methods(order.seller.fetch_store).collect(&:id).sort
        found_pm_ids = page.find_all("input[name='order[payments_attributes[][payment_method_id]]']").collect{|input| input['value'].to_i }.sort
        expect(found_pm_ids).to eq expected_pm_ids
        pm_id_selected = found_pm_ids.shuffle.first
        expect(pm_id_selected).not_to be_nil
      end

      if page.find_all("input[name='order[bill_address_id]']").blank?
        basic_address = find_or_create(:basic_address, :city)
        fill_in 'order[bill_address_attributes][firstname]', with: 'Mo'
        fill_in 'order[bill_address_attributes][lastname]', with: 'Power'
        fill_in 'order[bill_address_attributes][address1]', with: basic_address.address1
        fill_in 'order[bill_address_attributes][city]', with: basic_address.city
        if page.find_all("//select[name='order[bill_address_attributes][state_id]']").present?
          select basic_address.state.name, from: 'order[bill_address_attributes][state_id]'
        end
        fill_in 'order[bill_address_attributes][zipcode]', with: basic_address.zipcode
        select basic_address.country.name, from: 'order[bill_address_attributes][country_id]'
      end

      click_button Spree.t('save_and_continue')

      order.reload
      if Spree::Order::AUTO_SELECT_SHIPPING_METHOD
        expect(order.state).to eq 'complete'
        expect(page.current_path).to eq order_path(order)
      else
        if order.payments.any?
          expect(order.state).to eq 'complete'
          expect(page.current_path).to eq order_path(order)
        else
          expect(order.state).to eq 'delivery'
          expect(page.current_path).to eq checkout_state_path(state: order.state)
        end
      end

    else # original step by step checkout ###################################
      billing_addr_label = page.body.match( Regexp.new(I18n.t('spree.billing_address'), Regexp::IGNORECASE) )
      expect(billing_addr_label).not_to be_nil

      address = order.user.addresses.last || create(:basic_address)
      submit_billing_address(order, address)
      follow_redirect!

      # Should be delivery step next.  So far not working for test
      order.reload
      expect(order.state).to eq('delivery')
    end

    if order.state == 'complete' && Rails.env.production? # only production delay schedules this
      dj = Delayed::Job.for_record(order.seller).where(queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE).last
      expect(dj).not_to be_nil
      expect(dj.run_at >= order.created_at + Spree::User::NOTIFY_EMAIL_DELAY_LENGTH).to be_truthy
      dj_id = dj.id
      dj_run_at = dj.run_at
      handler_object = dj.handler_object
      p_method = dj.performable_method_name.to_sym
      dj.destroy

      run_time = Time.now # should be by delayed_jobs runner
      handler_object.send(p_method)
      dj2 = Delayed::Job.for_record(order.seller).where(queue: Spree::User::NOTIFY_EMAIL_DJ_QUEUE).last
      expect(dj2).not_to be_nil
      expect(dj_id).not_to eq(dj2.id)

      expect(dj2.run_at.to_i >= (run_time + Spree::User::NOTIFY_EMAIL_DELAY_LENGTH).to_i ).to be_truthy
    end

  end

  ##
  # The combined form submission.
  def checkout_together(order)
    unless order.state == 'complete'
      expect(order.confirmation_delivered).not_to be_truthy
    end
    address = order.user&.addresses&.last || create(:basic_address)
    if address.user_id.nil?
      address.user_id = order.user_id
      address.save
    end
    payment_method = order.available_payment_methods.find{|p| p.name =~ /paypal/i } ||
        order.available_payment_methods.first

    basic_params = { id: order.id, state: 'address', save_user_address: true,
                     transaction_code: order.transaction_code }
    
    old_mail_deliveries_count = ActionMailer::Base.deliveries.count

    patch update_checkout_path(
             basic_params.merge(
                 order: { state_lock_version: '0',
                          bill_address_id: address.id, use_billing: true,
                          payments_attributes: [{ payment_method_id: payment_method.id} ] }
             ) )
    order.reload

    expect(order.bill_address).to eq address
    expect(order.ship_address).to eq address

    expect(order.payments.any?).to be_truthy
    expect(order.completed?).to be_truthy
    expect(order.completed_at).not_to be_nil
    expect(order.state).to eq('complete')

    return if order.seller.phantom_seller?

    if Rails.configuration.action_mailer.delivery_method == :test
      check_mailer_deliveries(Spree::OrderMailer, :invoice_to_buyer, { order: order } ) do|found_m|
        check_mail_settings(order.user, found_m, 'gmail')
      end
      check_mailer_deliveries(Spree::OrderMailer, :new_order_to_seller, { order: order } ) do|found_m|
        check_mail_settings(order.seller, found_m, 
          order.seller.acceptable_send_to_email? ? 'gmail' : 'aliyun'
        )
        expect(found_m.to_s.match(/from\:\s*ioffer\shelper/i) ).not_to be_nil
      end
    end

    if order.respond_to?(:send_invoice_to_buyer_with_delay)
      djob = Delayed::Job.where(record_class: 'Spree::Order', record_id: order.id).last
      expect(djob).not_to be_nil
      handler = YAML::load(djob.handler)
      expect(handler.display_name).to eq('Spree::Order#send_invoice_to_buyer_without_delay')
      handler.perform
    end

    check_mailer_deliveries(Spree::OrderMailer, :invoice_to_buyer, order: order)
    check_mailer_deliveries(Spree::OrderMailer, :new_order_to_seller, order: order)
    
    order.reload
    expect(order.invoice_last_sent_at).not_to be_nil
    expect(order.confirmation_delivered).to be_truthy
  end

  ##
  # Starting from not-signed-in guest session, add to cart, and sign up after click to 
  # checkout.
  def test_signup_guest_and_buy_product(seller = nil)
    
    product = find_or_create(:basic_product, :name) {|p| p.user_id=seller&.id; p.available_on = 1.day.ago }

    puts "Seller product: #{product.name} --------------------"
    visit product_path(id: product.id)
    # cannot expect Add to Cart cuz spree needs cart JS to enable button
    # expect(page).to have_button('Add to Cart')

    added_return = process_add_to_cart_via_js(nil, product.master, { buyer: true })
    order = Spree::Order.last
    expect(order.user_id).to be_nil
    
    # make up for no-JS run
    visit cart_path

    puts 'Guest signs up an account --------------------'
    visit signup_path(buyer: true)
    fill_in 'Email', with: user_attr[:email]
    fill_in 'spree_user[password]', with: TEST_USER_PASSWORD
    fill_in 'spree_user[password_confirmation]', with: TEST_USER_PASSWORD
    click_button Spree.t('sign_up')

    buyer = Spree::User.last
    expect(buyer.email).to eq user_attr[:email]
    
    visit checkout_path(id: order.id)
    order.reload
    
    expect(order.user_id).to eq buyer.id

    order
  end

  ##
  # Test against whether user has permission to 
  # @reviewer [Spree::User] person that tries to create a review on a product
  def test_review_rating_to_product(reviewer, product, target_rating = nil)
    target_rating ||= rand(4) + 1
    puts " .. #{reviewer.to_s} wants to review #{product.name}(#{product.id})"

    create_params = { product_id: product.slug, 
      review: { rating: target_rating, name: reviewer.login, 
        title: "My rating for #{product.name}", review:"I give this #{target_rating} rating."
      } }
    post product_reviews_path(create_params)

    reviews_count = Spree::Review.where(user_id: reviewer.id, product_id: product.id).count
    if reviewer.has_ordered_product?(product.id)
      expect(reviews_count).to eq(1)

      post product_reviews_path(create_params)
      expect( Spree::Review.where(user_id: reviewer.id, product_id: product.id).count ).to eq(1)

    else
      expect(page.current_path).to eq(product_reviews_path(product_id: create_params[:product_id] ) )
      expect(reviews_count).to eq(0)
    end
  end

end