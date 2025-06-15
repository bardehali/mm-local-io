require File.join(Rails.root, 'app/helpers/controller_helpers/product_browser')

module Ioffer
  class ProductReviewGenerator < BaseGenerator
    include ControllerHelpers::ProductBrowser
    include ActiveRecord::CallbackModifier

    attr_accessor :settings

    SETTING_DEFAULTS = {
      dry_run: false,
      review_comments_file: File.join(Rails.root, 'data/product_review_comments.txt')
    }

    MAX_MINUTES_APART = 128 * 24 * 60
    REQUIRES_ORDER_CREATED = false
    REVIEW_TIME_FAKE_PAST = true

    ##
    # rating to percentage of possibility
    RATING_POSSIBILITY_PERCENTAGES = { 5 => 79, 4 => 15, 3 => 4, 2 => 1 }.freeze

    ##
    # For products w/ no price, start randomizing price at base price for the category
    BASE_PRICE_FOR_TAXONS = {
      /clothing\Z/i => 12,
      /\b(shoes?|sneakers?)\b/i => 15,
      /\b(jewelry|jewelries|watch|watches)\b/i => 20,
      /\b(bags?|handbags?|purses?|wallets?)\b/i => 30
    }



    ##
    # Products at beginning of category, count of random(50)+50 (50 to 100)
    #   count of reviews per product should be IQS/2 +/- random(10)
    #     1. Choose random user
    #     2. Create the purchase
    #     3. Create the review given random review string from list
    #     4. Give ~80% chance at 5 stars, ~15% chance at 4 stars, 3% chance at 3 stars, 1% chance at chance for 2 star, 1% chance at chance
    def batch_run_for_top_categories
      dry_run = settings[:dry_run]

      Spree::CategoryTaxon.root.children.each do|taxon|
        how_many_products = 50 + rand(50)
        puts '+' + ('-' * 80)
        puts "| Taxon: %40s (%6d): %2d products for review" % [taxon.name, taxon.id, how_many_products]

        @current_taxon_id = taxon.id
        @limit = how_many_products
        load_products_with_searcher()
        puts '+' + ('-' * 20) +" found #{@products.to_a.size} products " + ('-' * 40)

        batch_run_for(@products)
      end # each taxon

      user_list
    end

    ##
    # Generate a formual calculated number of reviews: (product.iqs.to_i / 2.0) + ( rand(20) - 10 ).
    # Generation of reviews requires users within the user_list.
    # @return [Array of Spree::Review]
    def batch_run_for(products)
      dry_run = settings[:dry_run]
      user_list = self.user_list
      user_g = Ioffer::UserGenerator.new(user_list_id: user_list.id, dry_run: dry_run)
      reviews = []

      set_skip_callbacks

      products.each do|product|
        how_many_reviews = [3, (product.iqs.to_i / 2.0) + ( rand(10) ) ].max # at least 3
        existing_count = product.reviews.joins(Spree::Review.user_list_user_users_joins_string).where(user_list_users: { user_list_id: user_list.id } ).count
        logger.debug '| %60s | %6d | %6.2f | %2d | %2d vs existing %2d' % [product.name.truncate(60), product.id, product.price.to_f, product.iqs, how_many_reviews, existing_count]

        count_to_create = [how_many_reviews - existing_count, 0].max
        user_g.batch_run_based_on(count_to_create, Ioffer::EmailSubscription, :email) do|user|
          begin
            rating = random_pick_a_rating

            order = REQUIRES_ORDER_CREATED ? make_an_order_of(user, product) : nil

            review = Spree::Review.new(product: product, user: user,
                name: user.display_name || user.login,
                rating: rating, title: random_pick_a_comment(rating),
                approved: true
              )
            if REVIEW_TIME_FAKE_PAST
              review.created_at = pick_create_time_for(user, product) - 3.days - rand(7 * 24).hours
            else
              review.created_at = (order&.created_at || pick_create_time_for(user, product) ) + 3.days + rand(7 * 24).hours
            end
            review.skip_check_permission = true
            # puts '    %40s => %d stars, at %s, %s' % [user.login, rating, review.created_at.to_s(:db), review.title]
            unless dry_run
              without_create_and_update_callbacks(review) do
                review.save(validate: false)
              end
            end
            reviews << review
          rescue Exception => e
            logger.warn "ERROR: #{e.message} ***********************\n#{e.backtrace.join("  \n")}"
            logger.warn "Product #{product.id}, user #{user}, review: #{review}\n******************************"
          end
        end
        product.skip_after_more_updates = true
        product.recalculate_rating
        product.skip_after_more_updates = false
      end
      reviews
    end

    def user_list_name
      super || 'fake_product_reviewers'
    end

    ##
    # Emulating methods of a controller
    def params
      @params ||= ActionController::Parameters.new({})
      @params[:taxon_ids] = @current_taxon_id if @current_taxon_id
      @params[:limit] = @limit if @limit
      @params
    end

    def spree_current_user
      nil
    end

    def logger
      Spree::ProductsController.logger
    end

    ###############################

    protected

    def normalize_settings(settings)
      SETTING_DEFAULTS.each_pair do|key, default_value|
        settings[key] = default_value if settings[key].nil?
      end
      settings
    end

    def random_pick_a_rating
      ratings = ratings_to_select
      ratings.sample
    end

    def ratings_to_select
      return @ratings_to_select if @ratings_to_select
      @ratings_to_select = []
      RATING_POSSIBILITY_PERCENTAGES.each_pair do|rating, percentage|
        1.upto(percentage) { @ratings_to_select << rating }
      end
      @ratings_to_select.shuffle!
      @ratings_to_select
    end

    def review_comments
      if @review_comments.blank?
        @review_comments = File.open( settings[:review_comments_file] ).readlines.reject(&:blank?)
      end
      @review_comments
    end

    GOOD_RATING_WORDS_REGEXP = /good|great|perfect|excellent|nice|wonderful|love/i

    ##
    # @return [String]
    def random_pick_a_comment(rating_value = nil)
      comments = nil
      if rating_value && [0, 1, 2, 3].include?(rating_value)
        comments = review_comments.reject{|c| c.match(GOOD_RATING_WORDS_REGEXP) }
      end
      comments ||= review_comments
      comments.sample
    end

    def make_an_order_of(user, product)
      order = Spree::Order.new(user_id: user.id, seller_user_id: product.user_id)

      order.created_at = pick_create_time_for(user, product)
      order.confirmation_delivered = true
      order.invoice_last_sent_at = order.created_at + 1.hour
      order.state = 'complete'
      order.completed_at = order.invoice_last_sent_at

      variant = product.variants_including_master.limit(10).to_a.shuffle.first
      line_item_h = { variant: variant, price: variant.price || find_price_for_taxon(product.taxons.first) }
      if settings[:dry_run]
        order.line_items << Spree::LineItem.new(line_item_h)
      else
        order.save
        order.line_items.create(line_item_h)
      end
      order
    end

    def find_price_for_taxon(taxon)
      price = nil
      BASE_PRICE_FOR_TAXONS.each_pair do|reg, base_price|
        if taxon && taxon.name.match(reg)
          price = base_price
          break
        end
      end
      price ||= (20 + rand(50))
      price + rand(price / 2)
    end

    # at least MAX_MINUTES_APART ago for really old products
    def pick_create_time_for(user, product)
      later_created_at = [MAX_MINUTES_APART.minutes.ago, product.created_at].max
      later_created_at = user.created_at if (user.created_at && user.created_at > later_created_at )
      later_created_at + 7.days + rand(MAX_MINUTES_APART).minutes
    end

    def set_skip_callbacks
    rescue ArgumentError => callback_e
      # rspec tests just don't have these callbacks set
      logger.warn "** #{callback_e.message}"
    end
  end
end
