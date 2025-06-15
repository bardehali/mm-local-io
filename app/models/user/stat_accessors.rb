module User
  module StatAccessors
    extend ActiveSupport::Concern

    included do
      extend ClassMethods
      
      has_many :user_stats, class_name:'User::Stat'

      COUNT_OF_CONTACT_INFO_INFRINGEMENTS = 'count_of_contact_info_infringements'
      COUNT_OF_BAD_BANNED_WORDS = 'count_of_bad_banned_words'
      COUNT_OF_PICTURES = 'count_of_pictures'
      COUNT_OF_PAID_NEED_TRACKING = 'count_of_paid_need_tracking_of_same_payment_account'
      REQUIRED_CRITICAL_RESPONSE = 'required_critical_response'
      AGREED_TO_LISTING_POLICY = 'agreed_to_listing_policy'
    end

    module ClassMethods
      def row_header
        ['ID', 'Username', 'Email', 'Roles', 'Seller rank', 'Last active', 'Last login time', 'Last login IP', 
          'Sign up IP', 'Sign up time', 'Paypal account', 'Paypal account start time', 'Paypal instruction',
          'Recent complaints in Paypal group', 'Recent transactions in Paypal group', 'Recent complaints/transctions ratio',
          'Count of sales', 'Count of products created', 'Count of products adopted', 'Transaction count'
        ]
      end
    end

    def total_count_of_ratings
      (positive.to_i + negative.to_i)
    end
  
    def rating_percentage
      if rating.to_f > 0.0
        rating
      elsif transactions_count.to_i > 0
        (transactions_count - negative.to_i) / transactions_count.to_f * 100
      else
        total_count_of_ratings > 0 ? (positive.to_f / total_count_of_ratings) * 100 : 0.0
      end
    end

    def created_products_count
      Spree::Product.where(user_id: id).count
    end
  
    def adopted_products_count
      Spree::Product.adopted_by(id).distinct.count
    end

    def sales_count(exclude_unreal_buyers = true)
      q = selling_orders.complete
      q = q.not_by_unreal_users if exclude_unreal_buyers
      q.count
    end

    def count_of_contact_info_infringements
      user_stats.find{|us| us.name == COUNT_OF_CONTACT_INFO_INFRINGEMENTS }.try(:value).to_i
    end

    def count_of_bad_banned_words
      user_stats.find{|us| us.name == COUNT_OF_BAD_BANNED_WORDS }.try(:value).to_i
    end

    def count_of_pictures
      user_stats.find{|us| us.name == COUNT_OF_PICTURES }.try(:value).to_i
    end

    def agreed_to_listing_policy?
      user_stats.find{|us| us.name == AGREED_TO_LISTING_POLICY }.try(:value).present?
    end

    ##
    # Calculate the necessary stats.
    def recalculate_user_stats!
      total_images_counts = Spree::Image.joins_with_variant.where(Spree::Variant.table_name => { user_id: id } ).count
      User::Stat.find_or_create_by(user_id: id, name: COUNT_OF_PICTURES).update(value: total_images_counts.to_s)

      count_of_contact = 0
      count_of_bad = 0

      Spree::Product.select('name,description').where(user_id: id).each do|p|
        count_of_contact += p.name.try(:scan, Filter::ContactInfo.regexp)&.size || 0
        count_of_contact += p.description.try(:scan, Filter::ContactInfo.regexp)&.size || 0
        count_of_bad += p.name.try(:scan, Filter::BadWord.regexp)&.size || 0
        count_of_bad += p.description.try(:scan, Filter::BadWord.regexp)&.size || 0
      end

      User::Stat.find_or_create_by(user_id: id, name: COUNT_OF_CONTACT_INFO_INFRINGEMENTS).update(value: count_of_contact.to_s)
      User::Stat.find_or_create_by(user_id: id, name: COUNT_OF_BAD_BANNED_WORDS).update(value: count_of_bad.to_s)


      {
        COUNT_OF_CONTACT_INFO_INFRINGEMENTS => count_of_contact,
        COUNT_OF_BAD_BANNED_WORDS => count_of_bad,
        COUNT_OF_PICTURES => total_images_counts
      }
    end

    def as_indexed_json(options = {})
      json = self.as_json(only:[:id, :email, :username, :created_at, :current_login_at, :current_login_ip,
        :created_at, :country, :seller_rank, :last_active_at] )
      # dynamic querying
      json['count_of_products_created'] = created_products_count
      json['count_of_products_adopted'] = adopted_products_count
      json
    end

    ##
    # @return [Array] values for use like CSV export
    # based on @row_header
    # 'id', 'username', 'email', 'roles', 'seller rank', 'last active', 'last login time', 'last login IP', 
    # 'sign up IP', 'sign up time', 'Paypal account', 'Paypal account start time', 'Paypal instruction',
    # 'recent complaints in Paypal group', 'recent transactions in Paypal group', 'recent complaints/transctions ratio',
    # 'count of sales', 'count of products created', 'count of products adopted', 'transaction count'
    def to_row
      sign_in_logs = self.sign_in_request_logs
      paypal = Spree::PaymentMethod.paypal unless defined?(paypal) && paypal
      paypal_store_pm = store ? store.store_payment_methods.where(payment_method_id: paypal.id).last : nil
      count_of_recent_payment_complaints = paypal_store_pm&.recent_orders_of_same_payment_method_account&.with_complaint&.count.to_i
      count_of_recent_orders = paypal_store_pm&.recent_orders_of_same_payment_method_account&.count.to_i

      [id, username, email, 
        spree_roles.collect{|r| r.name.gsub(/(_seller|_user)\Z/i, '').titleize }.join(' '), seller_rank,
        timestamp_with_slashes(last_active_at), timestamp_with_slashes(current_sign_in_at),
        current_sign_in_ip, sign_in_logs.first&.ip, timestamp_with_slashes(sign_in_logs.first&.created_at),
        paypal_store_pm&.account_id_in_parameters, timestamp_with_slashes(paypal_store_pm&.created_at),
        paypal_store_pm&.instruction, count_of_recent_payment_complaints, count_of_recent_orders,
        count_of_recent_payment_complaints.to_f / [count_of_recent_orders, 1].max, 
        sales_count, created_products_count, adopted_products_count, count_of_transactions
      ]
    end

  end
end