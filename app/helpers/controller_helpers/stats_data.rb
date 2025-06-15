module ControllerHelpers::StatsData
  extend ActiveSupport::Concern

  included do
    SQL_DAY_FORMAT = '%Y-%m-%d' unless defined?(SQL_DAY_FORMAT)
    SQL_DATE_AND_HOUR_FORMAT = '%Y-%m-%d %H' unless defined?(SQL_DATE_AND_HOUR_FORMAT)

    helper_method :load_counts_of_emails_delivered
    helper_method :load_counts_of_email_returns
    helper_method :load_counts_of_user_created
    helper_method :load_counts_of_email_subscriptions
    helper_method :load_counts_of_product_searches
  end

  def load_initial_dashboard_stats
    load_counts_of_emails_delivered(:day)
    load_counts_of_email_returns
    load_counts_of_user_created
    load_counts_of_email_subscriptions
    load_counts_of_product_searches
  end

  ##
  # [Hash of DateTime to Integer] with time descending
  def load_counts_of_emails_delivered(group_by = :day)
    data_var = group_by == :hour ? @counts_of_emails_delivered_per_hour : @counts_of_emails_delivered_per_hour
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
    data_var = group_by == :hour ? @counts_of_email_returns_per_hour : @counts_of_email_returns_per_hour
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
      where( all_users_created ? 'last_sign_in_at is not null' : ['last_sign_in_at is not null and created_at > ?', 1.month.ago.beginning_of_day] ).
      group("DATE_FORMAT(created_at, '#{SQL_DAY_FORMAT}')").count

    if Rails.env.development? && @counts_of_users_created_per_day.keys.size < 10
      31.downto(2) do|_days_ago|
        date_s = _days_ago.days.ago.strftime(group_by_s)
        @counts_of_users_created_per_day[date_s] = 20 + rand(10)
      end
    end
    @counts_of_users_created_per_day
  end

  def load_portions_of_countries
    @recent_total_count_of_users_created ||= 0
  end

  def load_counts_of_email_subscriptions
    return @counts_of_email_subscriptions_per_day if @counts_of_email_subscriptions_per_day
    group_by_s = SQL_DAY_FORMAT
    all_email_subscriptions = params[:all_email_subscriptions]
    @counts_of_email_subscriptions_per_day = Ioffer::EmailSubscription.select('created_at_date').
      where( all_email_subscriptions ? nil : ['created_at > ?', 1.month.ago.beginning_of_day] ).
      group("created_at_date").count

    if Rails.env.development? && @counts_of_email_subscriptions_per_day.keys.size < 10
      31.downto(2) do|_days_ago|
        date_s = _days_ago.days.ago.strftime(group_by_s)
        @counts_of_email_subscriptions_per_day[date_s] = 20 + rand(10)
      end
    end
    @counts_of_email_subscriptions_per_day
  end


  def load_counts_of_product_searches(limit = 30)
    return @counts_of_product_searches if @counts_of_product_searches
    all_recent_product_searches = params[:all_recent_product_searches]
    @counts_of_product_searches = SearchLog.group(:keywords).order('COUNT(*) DESC').limit(limit).count
  end
end