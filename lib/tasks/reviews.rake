require 'csv'
require 'mail'
require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

namespace :reviews do

  task :recalculate_ratings => [:environment] do
    trap_signal_and_exit
    convert_env_variables
    batch_index = 0
    print_beginning_info

    q = Spree::Product.joins('inner join spree_reviews on spree_products.id=spree_reviews.product_id')
    unless ENV['FORCE'].to_s == 'true'
      q = q.where("avg_rating=0.0")
    end
    q = apply_more_to_query(q)
    
    puts "| Query: #{q.to_sql}"
    puts "| Total: #{q.count}"
    q.in_batches(of: 50) do|subq|
      puts "Batch #{batch_index} at #{Time.now}"
      subq.includes(:reviews).each do|p| 
        p.skip_after_more_updates = true
        p.recalculate_rating 
      end
      batch_index += 1
    end
    print_ending_info
  end

  ##
  # rake reviews:generate_fakes
  # environment variables considered:
  #   DRY_RUN
  #   USER_LIST_NAME - if not specified would use Ioffer::ProductReviewGenerator#user_list_name
  #   RETAIL_SITE_ID - ID of Retail::Site.  If not specified, would be top categories
  #   RETAIL_SITE_NAME - name of Retail::Site.  If not specified, would be top categories
  #   PRODUCT_WHERE - Instead of Product.where(retail_site: site.id), use this in where.
  task :generate_fakes => [:environment] do
    dry_run = ENV['DRY_RUN']=='true' # 
    puts "Dry run? #{dry_run}"

    user_list_name = ENV['USER_LIST_NAME']
    retail_site_id = ENV['RETAIL_SITE_ID'].to_i 
    retail_site_name = ENV['RETAIL_SITE_NAME']
    product_where = ENV['PRODUCT_WHERE']

    review_g = Ioffer::ProductReviewGenerator.new(dry_run: dry_run, user_list_name: user_list_name)
    puts "user_list_name: #{review_g.user_list_name}"

    retail_site_conds = {}
    retail_site_conds[:id] = retail_site_id if retail_site_id > 0
    retail_site_conds[:name] = retail_site_name if retail_site_name.present?
    puts "retail_site_conditions: #{retail_site_conds}"

    puts "product_where: #{product_where}" if product_where

    if retail_site_conds.size > 0
      retail_site = Retail::Site.where(retail_site_conds).first
      if retail_site || product_where.present?
        user_list = review_g.user_list
        user_g = Ioffer::UserGenerator.new(user_list_id: user_list.id, dry_run: dry_run)

        query = Spree::Product.where(product_where.present? ? product_where : 
          {retail_site_id: retail_site.id} )
        puts "Total: #{query.count} products"
        puts '+' + ('-' * 80)

        query.in_batches(of: 100, start: 1).each do|subq|
          review_g.batch_run_for(subq.all )
        end

      else
        puts '** No such retail site'
      end
    else
      review_g.batch_run_for_top_categories
    end

    user_list = review_g.user_list

    # assign countries to created users in $user_list
    user_g = Ioffer::UserGenerator.new(user_list_id: user_list.id, dry_run: dry_run)
    user_g.distribute_countries_to( Spree::User.unscoped.joins(:user_list_users).where(user_list_users:{ user_list_id: user_list.id}) )
  end
end
