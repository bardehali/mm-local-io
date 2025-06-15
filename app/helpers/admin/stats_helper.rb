module Admin::StatsHelper
  extend ActiveSupport::Concern

  SQL_DAY_FORMAT = '%Y-%m-%d' unless defined?(SQL_DAY_FORMAT)
  SQL_DATE_AND_HOUR_FORMAT = '%Y-%m-%d %H' unless defined?(SQL_DATE_AND_HOUR_FORMAT)
  PER_DAY_LABELS = ['Today', 'Yesterday', 'Last Week', '1 Month', '2 Months']
  PER_DAY_SHORT_LABELS = ['Today', 'Y', 'LW', 'LM', '2M']

  ##
  # [Hash of DateTime to Integer] with time descending
  def load_counts_of_emails_delivered(group_by = :day)
    data_var = group_by == :hour ? @counts_of_emails_delivered_per_hour : @counts_of_emails_delivered_per_day
    return data_var if data_var
    group_by_s = group_by == :hour ? SQL_DATE_AND_HOUR_FORMAT : SQL_DAY_FORMAT
    all_email_camp_deliveries = params[:all_email_campaign_deliveries]

    if group_by == :hour
      data_var = @counts_of_emails_delivered_per_hour = HashWithIndifferentAccess.new
    else
      data_var = @counts_of_emails_delivered_per_day = HashWithIndifferentAccess.new
    end
    h = Spree::EmailCampaignDelivery.select('delivered_at').
      where( all_email_camp_deliveries ? 'delivered_at is not null' : ['delivered_at > ?', 1.month.ago.beginning_of_day] ).
      group("DATE_FORMAT(delivered_at, '#{group_by_s}')").count

    # sample data
    if Rails.env.development? && @counts_of_emails_delivered_per_day.blank?
      31.downto(2) do|_days_ago|
        if group_by == :hour
          24.downto(1) do|_hours_ago|
            date_s = (_days_ago.days.ago + _hours_ago.hours.ago).strftime(group_by_s)
            h[date_s] = 30 + rand(10)
          end
        else
          date_s = _days_ago.days.ago.strftime(group_by_s)
          h[date_s] = 30 + rand(10)
        end
      end
    end

    # Convert to DateTime
    #h.keys.sort.reverse_each do|date_s|
    #  local_time = Time.parse("#{date_s}#{date_s == :hour ? ':00:00' : ' 00:00:00'} +0000").in_time_zone(-5)
      # data_var[local_time] = h[date_s]
    #end
    data_var = h
    data_var
  end

  def load_counts_of_email_returns(group_by = :day)
    data_var = group_by == :hour ? @counts_of_email_returns_per_hour : @counts_of_email_returns_per_day
    return data_var if data_var

    group_by_s = group_by == :hour ? SQL_DATE_AND_HOUR_FORMAT : SQL_DAY_FORMAT
    all_email_camp_deliveries = params[:all_email_campaign_deliveries]
    time_column = "#{Spree::User.table_name}.last_email_at"
    if group_by == :hour
      data_var = @counts_of_email_returns_per_hour
    else
      data_var = @counts_of_email_returns_per_day
    end
    data_var = RequestLog.joins(:user).select(time_column).
      where("group_name='show_reset_password'").
      where( all_email_camp_deliveries ? "#{time_column} is not null" : ["#{time_column} > ?", 1.month.ago.beginning_of_day] ).
      group("DATE_FORMAT(#{RequestLog.table_name}.created_at,'#{group_by_s}')").count

    if Rails.env.development? && @counts_of_email_returns_per_day.blank?
      31.downto(2) do|_days_ago|
        if group_by == :hour
          24.downto(1) do|_hours_ago|
            date_s = (_days_ago.days.ago + _hours_ago.hours.ago).strftime(group_by_s)
            data_var[date_s] = 20 + rand(10)
          end
        else
          date_s = _days_ago.days.ago.strftime(group_by_s)
          data_var[date_s] = 20 + rand(10)
        end
      end
    end
    data_var
  end

  def load_counts_of_user_created
    return @counts_of_users_created_per_day if @counts_of_users_created_per_day
    group_by_s = SQL_DAY_FORMAT
    all_users_created = params[:all_users_created]
    @counts_of_users_created_per_day = Spree::User.select('created_at').
      where( all_users_created ? 'last_sign_in_at is not null' : ['last_sign_in_at is not null and created_at > ?', 14.days.ago.beginning_of_day] ).
      group("DATE_FORMAT(created_at, '#{SQL_DAY_FORMAT}')").count

    if Rails.env.development? && @counts_of_users_created_per_day.keys.size < 10
      14.downto(2) do|_days_ago|
        date_s = _days_ago.days.ago.strftime(group_by_s)
        @counts_of_users_created_per_day[date_s] = 20 + rand(10)
      end
    end
    @counts_of_users_created_per_day
  end

  def load_counts_of_sellers_per_country(value_type = 'percentage')
    @counts_of_sellers_per_country ||= load_top_counts_of_query( Spree::User.sellers.real_users, :country, value_type)
  end

  def load_counts_of_buyers_per_country(value_type = 'percentage')
    @counts_of_buyers_per_country ||= load_top_counts_of_query( Spree::User.buyers, :country, value_type )
  end

  def load_counts_of_email_subscriptions
    return @counts_of_email_subscriptions_per_day if @counts_of_email_subscriptions_per_day
    group_by_s = SQL_DAY_FORMAT
    all_email_subscriptions = params[:all_email_subscriptions]
    @counts_of_email_subscriptions_per_day = Ioffer::EmailSubscription.select('created_at_date').
      where( all_email_subscriptions ? nil : ['created_at > ?', 1.month.ago.beginning_of_day] ).
      group("created_at_date").count

    if Rails.env.development? && @counts_of_email_subscriptions_per_day.keys.size < 10
      14.downto(2) do|_days_ago|
        date_s = _days_ago.days.ago.strftime(group_by_s)
        @counts_of_email_subscriptions_per_day[date_s] = 20 + rand(10)
      end
    end
    @counts_of_email_subscriptions_per_day
  end


  def load_counts_of_product_searches(limit = 30)
    return @counts_of_product_searches if @counts_of_product_searches
    all_recent_product_searches = params[:all_recent_product_searches]
    @counts_of_product_searches = load_top_counts_of_query(SearchLog.unscoped, 'keywords', 'count', limit)
    @counts_of_product_searches
  end

  def load_txns_per_day(labels = nil)
    labels ||= PER_DAY_LABELS
    load_per_day_stats(::Spree::Order.complete, 'completed_at', 'txns', labels)
  end

  def load_txns_per_day_in_hash(labels = nil)
    results = load_txns_per_day(labels)
    instance_v = ActiveSupport::HashWithIndifferentAccess.new
    instance_v_queries = ActiveSupport::HashWithIndifferentAccess.new
    results.each do|result|
      instance_v[result.label ] = result.amount
      instance_v_queries[result.label ] = result.query
    end
    instance_variable_set("@txns_per_day_queries", instance_v_queries)
    instance_v
  end

  def load_txns_daily
    load_daily '@txns_daily', Spree::Order.complete, 'completed_at'
  end


  def load_unique_buyers_per_day(labels = nil)
    labels ||= PER_DAY_LABELS
    load_per_day_stats(::Spree::Order.complete.select('DISTINCT user_id'), 'completed_at', 'unique_buyers', labels)
  end

  def load_unique_buyers_per_day_in_hash(labels = nil)
    results = load_unique_buyers_per_day(labels)
    instance_v = ActiveSupport::HashWithIndifferentAccess.new
    instance_v_queries = ActiveSupport::HashWithIndifferentAccess.new
    results.each do |result|
      instance_v[result.label] = result.amount
      instance_v_queries[result.label] = result.query
    end
    instance_variable_set("@unique_buyers_per_day_queries", instance_v_queries)
    instance_v
  end

  def load_unique_buyers_daily
    load_daily '@unique_buyers_daily', Spree::Order.complete.select('DISTINCT user_id'), 'completed_at'
  end



  def load_added_to_cart_per_day(labels = nil)
    labels ||= PER_DAY_LABELS
    load_per_day_stats(::Spree::LineItem, 'created_at', 'added_to_cart', labels)
  end

  def load_added_to_cart_per_day_in_hash(labels = nil)
    results = load_added_to_cart_per_day(labels)
    instance_v = ActiveSupport::HashWithIndifferentAccess.new
    instance_v_queries = ActiveSupport::HashWithIndifferentAccess.new
    results.each do|result|
      instance_v[result.label ] = result.amount
      instance_v_queries[result.label ] = result.query
    end
    instance_variable_set("@added_to_cart_per_day_queries", instance_v_queries)
    instance_v
  end

  def load_added_to_cart_daily
    load_daily '@added_to_cart_daily', Spree::LineItem.where(nil), 'created_at'
  end




  def load_unique_added_to_cart_per_day(labels = nil)
    labels ||= PER_DAY_LABELS
    load_per_day_stats(::Spree::LineItem.select('DISTINCT request_ip'), 'created_at', 'unique_added_to_cart', labels)
  end

  def load_unique_added_to_cart_per_day_in_hash(labels = nil)
    results = load_unique_added_to_cart_per_day(labels)
    instance_v = ActiveSupport::HashWithIndifferentAccess.new
    instance_v_queries = ActiveSupport::HashWithIndifferentAccess.new
    results.each do |result|
      instance_v[result.label] = result.amount
      instance_v_queries[result.label] = result.query
    end
    instance_variable_set("@unique_added_to_cart_per_day_queries", instance_v_queries)
    instance_v
  end


  def load_unique_added_to_cart_daily
    load_daily '@unique_added_to_cart_daily', Spree::LineItem.select('DISTINCT request_ip'), 'created_at'
  end





  def load_complaints_per_day(labels = nil)
    labels ||= PER_DAY_SHORT_LABELS
    load_per_day_stats(::Spree::Order.complete.joins(:complaint), "#{::Spree::Order.table_name}.completed_at", 'complaints', labels)
  end

  def load_item_views_per_day(labels = nil)
    labels ||= PER_DAY_LABELS
    load_per_day_stats(RequestLog.where(group_name:'view_product'), 'created_at', 'view_product', labels)
  end

  def load_item_views_per_day_in_hash(labels = nil)
    results = load_item_views_per_day(labels)
    instance_v = ActiveSupport::HashWithIndifferentAccess.new
    instance_v_queries = ActiveSupport::HashWithIndifferentAccess.new
    results.each do|result|
      instance_v[result.label ] = result.amount
      instance_v_queries[result.label ] = result.query
    end
    instance_variable_set("@item_views_per_day_queries", instance_v_queries)
    instance_v
  end

  def load_item_views_daily
    load_daily '@item_views_daily', RequestLog.where(group_name:'view_product'), 'created_at'
  end

  ##
  # @options
  #   :limit [Integer] default 10
  #   :start_time [DateTime] default: nil
  #   :end_time [DateTime] default: nil
  #   :value_type [String] 'count' or 'percentage'; default 'count'
  def load_txns_by_country(options = {})
    limit = options[:limit] || 10
    value_type = options[:value_type] || 'count'
    start_time = options[:start_time]
    end_time = options[:end_time]
    @txns_by_country ||= {}
    @txns_by_country_queries ||= {}
    txns_map = @txns_by_country[options.as_json]
    return txns_map if txns_map

    # Trim down to top ones

    txns_map = ActiveSupport::HashWithIndifferentAccess.new
    raw_txns_by_country_q = Spree::Order.complete
    raw_txns_by_country_q = raw_txns_by_country_q.where('completed_at >= ?', start_time) if start_time
    raw_txns_by_country_q = raw_txns_by_country_q.where('completed_at < ?', end_time) if end_time
    raw_txns_by_country_q = raw_txns_by_country_q.joins(:user).select("country").group('country')
    raw_txns_by_country = raw_txns_by_country_q.count
    if Rails.env.development? && raw_txns_by_country.size < 5
      raw_txns_by_country = Spree::User.group('country').count
    end
    total_count = 0
    countries_by_txns = {}
    raw_txns_by_country.each_pair do|country, cnt|
      next if country.blank?
      total_count += cnt
      countries_by_txns.add_into_list_of_values(cnt, country)
    end

    countries_by_txns.keys.sort.reverse.each do|cnt|
      countries = countries_by_txns[cnt]
      countries[0, limit - txns_map.size - 1].each do|country|
        txns_map[ country ] = (value_type == 'percentage') ?
          (cnt.to_f / total_count * 1000).to_i / 10.0 : cnt
        # logger.debug "| #{cnt} => #{country} out of #{countries.size} | now total #{txns_map.size}"
      end
      break if txns_map.size >= limit
    end
    if raw_txns_by_country.size > limit
      if value_type == 'percentage'
        txns_map['Others']  = (100.0 - txns_map.values.sum).to_i
      else
        txns_map['Others']  = total_count - txns_map.values.sum
      end
    end
    @txns_by_country[options.as_json] = txns_map
    @txns_by_country_queries[options.as_json] = raw_txns_by_country_q.to_sql
    logger.debug "| txns_map of #{options.as_json}:\n| #{txns_map.to_yaml}"
    txns_map
  end

  # @return [Array of Hash w/ keys (:label, :old_value, :new_value, :difference)]
  def load_txn_country_trends(limit = 20)
    today_exact_time = Time.now.beginning_of_day + 10.hours
    @txn_country_trends_queries = ActiveSupport::HashWithIndifferentAccess.new

    now_options = { limit: limit + 1, start_time: today_exact_time - 30.days, end_time: today_exact_time }
    txns_now_h = load_txns_by_country(now_options)
    @txn_country_trends_queries['Now'] = @txns_by_country_queries ? @txns_by_country_queries[now_options.as_json] : nil

    old_options = { limit: limit + 1, start_time: today_exact_time - 60.days, end_time: today_exact_time - 30.days }
    old_txns_h = load_txns_by_country(old_options)
    @txn_country_trends_queries['Old'] = @txns_by_country_queries ? @txns_by_country_queries[old_options.as_json] : nil

    merged_countries = txns_now_h.keys | old_txns_h.keys
    merged_list = []
    merged_countries[0, limit].each do|country|
      values =
        if Rails.env.development?
          cnt = 50 + rand(50)
          { label: country, old_value: (cnt + rand(cnt / 2) - (cnt / 4)).to_i, new_value: (cnt + rand(cnt / 2) - (cnt / 4)).to_i }
        else
          { label: country, old_value: old_txns_h[country] , new_value: txns_now_h[country] }
        end
        values[:difference] = ( values[:old_value].nil? ? 1.0 : ((values[:new_value].to_f - values[:old_value]) / values[:old_value]) ) * 100.0
      merged_list << values
    end
    merged_list.sort!{|x, y| y[:difference] <=> x[:difference] }
    logger.debug "merged_list: #{merged_list}"
    merged_list
  end

  ##
  # @start_time default beginning of day
  def load_buyers(start_time = nil, end_time = nil)
    q = Spree::User.left_joins(:role_users).where("#{Spree::RoleUser.table_name}.role_id IS NULL")
    q = apply_time_limit_to_query(q, 'created_at', start_time, end_time)
    q
  end

  def load_sellers(start_time = nil, end_time = nil)
    q = Spree::User.real_sellers
    q = apply_time_limit_to_query(q, 'created_at', start_time, end_time)
    q
  end

  def load_products(start_time = nil, end_time = nil)
    q = Spree::Product.not_by_unreal_users
    q = apply_time_limit_to_query(q, 'created_at', start_time, end_time)
    q
  end

  private

  # For environment like development might be short of data, so no time limit.
  def apply_time_limit_to_query(query, time_attribute = 'created_at', start_time = nil, end_time = nil)
    unless Rails.env.test? || Rails.env.development?
      q = query.where("#{query.table_name}.#{time_attribute} > ?", start_time || Time.now.in_time_zone.beginning_of_day )
      q = q.where("#{query.table_name}.#{time_attribute} < ?", end_time) if end_time
      q
    else
      query
    end
  end

  StatResult = Struct.new(:label, :amount, :start_time, :end_time, :query)

  ##
  # @base_query [ActiveRecord::Relation] initial query that'd have where condition added
  #   w/ time range for @time_column
  # @time_column [String] like 'completed_at' for Order
  # @variable_prefix [String] for example, 'txns' would generate @txns_per_day
  #   and @txns_per_day_queries
  # @return [Array of StatResult]
  def load_per_day_stats(base_query, time_column, variable_prefix, labels, &block)
    instance_v = instance_variable_get("@#{variable_prefix}_per_day")
    return instance_v if instance_v
    instance_v = []
    labels ||= PER_DAY_LABELS

    start_time = Time.now.in_time_zone.beginning_of_day
    time_of_day = Time.now.in_time_zone - start_time
    [1.second, 1.day, 7.days, 28.days, 56.days].each_with_index do|time_diff, i|
      exact_time = start_time - time_diff
      q = base_query.where("#{time_column} between ? and ?", exact_time, exact_time + time_of_day)
      amount = if Rails.env.development? # fake data
        30 + rand(10) - 5
      else
        variable_prefix == 'complaints' ?
          q.count("DISTINCT(#{base_query.model.table_name}.id)") : q.count
      end
      instance_v << StatResult.new( labels[i], amount,
        exact_time, exact_time + time_of_day, q.to_sql )
    end

    instance_variable_set("@#{variable_prefix}_per_day", instance_v)
    instance_v
  end

  ##
  # Common daily counts
  # @base_query [ActiveRecord_Relation]
  # @time_attribute [String] the column/attribute for time range condition, for example completed_at or created_at
  def load_daily(instance_variable_name, base_query, time_attribute)
    ivar = instance_variable_get(instance_variable_name)
    return ivar if ivar
    ivar = []
    daily_queries = ActiveSupport::HashWithIndifferentAccess.new
    timezone = 'Eastern Time (US & Canada)' # Define your timezone here

    if Rails.env.development?
      19.downto(1) do |i|
        cnt = 30 + rand(10) - 5
        the_day = (Time.now.in_time_zone(timezone) - i.days)
        _label = the_day.strftime("%a").upcase[0,3] + the_day.strftime("-%d")
        ivar << [_label, cnt]
        daily_queries[_label] = 'SOME Queries'
      end
    else
      19.downto(1) do |i|
        the_day = Time.now.in_time_zone(timezone) - i.days
        exact_time = the_day.beginning_of_day
        q = base_query.where("#{time_attribute} between ? and ?", exact_time, exact_time + 1.day)
        _label = the_day.strftime("%a").upcase[0,2] + the_day.strftime("-%d")
        ivar << [_label, q.count]
        daily_queries[_label] = q.to_sql
      end
    end

    instance_variable_set(instance_variable_name + '_queries', daily_queries)
    instance_variable_set(instance_variable_name, ivar)
    ivar
  end


  # Common top counts
  def load_top_counts_of_query(query, column, value_type, limit = 10)
    query = apply_time_limit_to_query( query )
    total_count = query.count
    h = query.group(column).order("COUNT(#{column}) DESC").limit(limit).count
    logger.debug "query: #{query.to_sql}\n#{h}"
    if value_type.to_s == 'percentage'
      h.each_pair do|key, value|
        h[key] = (value.to_f / total_count * 1000).to_i / 10.0 # trim down to 1 decimal
      end
    end
    logger.debug "result: #{h}"
    h
  end
end
