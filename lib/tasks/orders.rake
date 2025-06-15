require 'csv'

namespace :orders do
  desc 'Split existing orders into seller-specific orders'
  task :split_by_sellers => [:environment] do
    query = Spree::Order.incomplete.includes(line_items: :variant)
    puts "Total incomplete orders: #{query.count}"
    cart_create_service = Spree::Api::Dependencies.storefront_cart_create_service.constantize
    add_item_service = Spree::Api::Dependencies.storefront_cart_add_item_service.constantize
    query.each do|order|
      seller_to_line_items = order.line_items.group_by{|li| li.variant.user_id }
      puts "Order #{order.id} of user #{order.user_id} has #{seller_to_line_items.size} sellers"
      next if seller_to_line_items.size == 0
      seller_to_line_items.each_pair do|seller_user_id, line_items|
        seller_store = Spree::User.find(seller_user_id).fetch_store
        seller_order = cart_create_service.call(
          user: order.user, store: seller_store, currency: order.currency, 
        ).value
        seller_order.update(seller_user_id: seller_user_id)
        line_items.each do|line_item|
          add_item_service.call(
            order: seller_order, variant: line_item.variant, quantity: line_item.quantity
          )
        end
      end
      order.destroy
    end
  end

  ##
  # Syntax:
  #  rake orders:export_line_items_csv optional_file_name_or_path
  #    @optional_file_name_or_path - if none, would be $stdout; if not complete path, would be in shared/data/
  desc 'Query line items and their products and users; export to CSV'
  task :export_line_items_csv => [:environment] do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    output_file = ARGV.shift
    output = if output_file.present?
      output_file = File.join(Rails.root, 'shared/data/', output_file) if output_file.index('/').nil?
      File.open( output_file, 'w')
    else
      $stdout
    end

    exclude_role_ids = Spree::Role.where(name: %w(test_user curated_user fake_user)).all.collect(&:id)

    headers = %w(item_id title user_id user_email user_country added_to_cart_time order_state)
    headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
    output.puts headers_row.to_s

    Spree::LineItem.includes(:product).includes(order:{ user: :role_users }).joins(:order).order('spree_line_items.product_id asc, spree_line_items.id asc').each do|line_item|
      next if line_item.order.user.nil?
      next if ( line_item.order.user.role_users.collect(&:role_id) & exclude_role_ids ).size > 0
      col_values = [line_item.product_id, line_item.product.name, line_item.order.user_id, line_item.order.user.email, line_item.order.user.country, line_item.created_at, line_item.order.state]
      row = CSV::Row.new(headers, col_values)
      output.puts row.to_s
    end

    output.close if output.is_a?(File)
  end

  desc 'Query orders by real sellers and buyers; export to CSV'
  task :export_to_csv => [:environment] do
    ARGV.each { |a| task a.to_sym do ; end }
    ARGV.shift
    output_file = ARGV.shift
    output = if output_file.present?
      output_file = File.join(Rails.root, 'shared/data/', output_file) if output_file.index('/').nil?
      File.open( output_file, 'w')
    else
      $stdout
    end

    ALL_ORDERS = (ENV['ORDERS_GROUP'] != 'REAL')

    headers = ['ID', 'Number', 'Date', 'Seller ID', 'Seller Email', 'Days Since Seller Login', 'Buyer Email', 'Payment Processor', 'Payment Instructions', 'Marked as Paid?', 'Seller User Role', 'Price']
    headers_row = CSV::Row.new(headers.collect(&:to_sym), headers, true)
    output.puts headers_row.to_s

    query = apply_more_to_query( Spree::Order.complete )
    unless ALL_ORDERS
      query = query.not_bought_by_unreal_users
    end
    query.includes(:user, :seller => [:spree_roles], :payments => [:payment_method] ).each do|o|
      next if o.user.nil? || !ALL_ORDERS && (o.seller_user_id.nil? || o.seller.nil? || o.seller.admin? || o.seller.test_or_fake_user?)
      col_values = [o.id, o.number, o.created_at.in_time_zone.to_s(:long), o.seller_user_id, o.seller&.email, 
        o.seller&.days_inactive.to_s,
        o.user&.email, o.payments.first&.payment_method&.description, o.special_instructions, 
        o.paid?, o.seller.try(:spree_roles).to_a.collect(&:name).join(' '), o.total]
      row = CSV::Row.new(headers, col_values)
      output.puts row.to_s
    end

    output.close if output.is_a?(File)
  end
end