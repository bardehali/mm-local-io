require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

namespace :db do
  task :import_from_seeds => [:environment] do
    ARGV.shift
    seeds_file = ARGV.shift
    puts "seeds file: #{seeds_file}"
    puts '=' * 60
    load seeds_file
  end

  desc "Dumps the database to file"
  task :mysql_dump => :environment do
    ARGV.each { |a| task a.to_sym do ; end }
    version = ARGV[1] 
    version = Time.now.to_s(:db).gsub(/([\s\-\:]+)/, '') if version.blank?
    cmd = "echo 'No action'"
    with_config do |host, db, user, password, socket|
      file_path = data_full_path("#{db}.#{version}.sql" )
      puts "Dumping to file: #{file_path}"
      auth_arguments = "-h#{host} -u#{user} -p#{password} --socket=#{socket}"
      cmd = "mysqldump --complete-insert --opt #{auth_arguments} #{db} > \"#{file_path}\""
    end
    if cmd.present?
      print_beginning_info
      exec cmd
      print_ending_info
      puts "File size: #{ File.size(file_path) / 1000000 } MB"
    end
  end

  desc "Recreates and restores the database dump"
  task :mysql_restore => :environment do
    ARGV.each { |a| task a.to_sym do ; end }
    cmd = "echo 'No action'"
    version = ARGV[1]
    full_path = version.try(:index, '/') ? version : nil
    with_config do |host, db, user, password, socket|
      if full_path.blank? 
        d = default_data_directory
        if version.blank?
          # Just latest .sql in default data directory
          full_path = Dir.glob("#{d}/#{db}*.sql").sort{|p1, p2| File.mtime(p1) <=> File.mtime(p2) }.last
        else
          full_path = File.join(d, "#{db}.#{version}.sql")
          full_path = nil if not File.exists?(full_path)
        end
      end

      if full_path.blank?
        raise ArgumentError.new("No SQL dump file found for #{db}")
      end

      print_beginning_info
      puts "Using dump file: #{full_path}"
      auth_arguments = "-h#{host} -u#{user} -p#{password} --socket=#{socket}"
      cmd = "mysql #{auth_arguments} -D#{db} < \"#{full_path}\""

      if full_path.blank?
        raise ArgumentError.new("No SQL dump file found for #{db}")
      else
        begin
          exec "mysqladmin #{auth_arguments} -f drop #{db}"
        rescue Exception => db_e
          puts "** Error dropping #{db}: #{db_e.message}"
        end
		    exec "mysqladmin #{auth_arguments} create #{db}"
        exec cmd
        print_ending_info
      end
    end
  end

  task :erase_user_data => :environment do
    erase_orders
    erase_products
    erase_users
  end

  task :erase_products => :environment do
    erase_orders
    erase_products
  end

  ########################
  # 
  #############################

  def erase_products
    query = ::Spree::Product.with_deleted
    puts "%d products to erase" % [query.count]
    query.each do|p|
      begin
        p.really_destroy!
      rescue Elasticsearch::Transport::Transport::Error
        puts "** Problem deleting product(#{p.id})"
      end
    end
  end

  def erase_orders
    ::Spree::Order.all.each do|order|
      begin
        order.return_authorizations.each(&:destroy)
        order.reimbursements.each(&:destroy)

        order.order_promotions.each(&:destroy)

        order.all_adjustments.each(&:destroy)
        order.shipment_adjustments.each(&:destroy)
        order.line_item_adjustments.each(&:destroy)

        order.inventory_units.each(&:destroy)
        order.shipments.each(&:destroy)

        order.payments.each(&:destroy)
        order.line_items.each(&:destroy)

        order.state_changes.each(&:destroy)
        order.destroy
      rescue Exception => delete_e
        puts "** Order(#{order.id}) destroy error #{delete_e.message}"
      end
    end
  end

  # Except admins
  def erase_users
    query = ::Spree::User.with_deleted
    puts "%d users to erase" % [query.count]
    query.includes(:store, :spree_roles).each do|u|
      next if u.admin?
      if u.store
        u.store.destroy
      end

      ::Retail::StoreToSpreeUser.all.each(&:destroy)
      u.addresses.each(&:destroy)
      u.credit_cards.each(&:destroy)
      u.role_users.each(&:destroy)
      u.reload
      u.really_destroy!
    end
    # Spree::ShippingMethod.all.each{|sm| sm.destroy if sm.user && !sm.user.admin? }
  end

  private

  def with_config
    yield ActiveRecord::Base.connection_config[:host],
      ActiveRecord::Base.connection_config[:database],
      ActiveRecord::Base.connection_config[:username],
      ActiveRecord::Base.connection_config[:password],
      ActiveRecord::Base.connection_config[:socket]
  end

  def default_data_directory
    data_dir = File.join(Rails.root, 'shared/data')
    data_dir = File.join(Rails.root, 'data') if not Dir.exists?(data_dir)
    FileUtils.mkdir_p(data_dir)
    data_dir
  end

  def data_full_path(file_path = nil)
    if file.blank? || file_path.index('/').nil?
      File.join(default_data_directory, file_path)
    else
      file_path
    end
  end
end