module Spree::Admin::UsersControllerDecorator

  def self.prepended(base)
    base.include ::ControllerHelpers::FileStreamer

    base.helper Rails.application.routes.url_helpers # those routes outside of Spree::Core::Engine.add_routes
    base.helper Spree::Core::Engine.routes.url_helpers

    base.helper Spree::Admin::MoreUsersHelper
    base.before_action :check_from_show_to_edit, only: [:show]
    base.before_action :load_user_list, only: [:index, :sellers, :buyers]
    base.before_action :convert_search_params

    base.helper_method :filter
  end

  def buyers
    named_users
  end

  def sellers
    named_users
  end

  def all_sellers
    named_users
  end

  ##
  #
  def old_simple_sellers
    params[:q] ||= {}
    params[:q][:s] = 'ioffer_user_gms desc' if params[:q][:s].blank?

    @search = Spree::User.ransack(params[:q])
    @sellers = @search.result.includes(:ioffer_user, :request_logs, retail_store_to_user: [:retail_site]).page(params[:page]).per(Spree::Config[:admin_users_per_page])
  end

  def soft_delete
    params.permit(:id, user_report:[:comment] )
    load_resource
    @user.soft_delete!(params[:user_report].try(:to_unsafe_h) )
    redirect_to edit_admin_user_path(id: @user.id, t: Time.now.to_i)
  end

  def restore
    load_resource
    @user.restore_status!
    redirect_to edit_admin_user_path(id: @user.id, t: Time.now.to_i)
  end

  def limit_user
    permitted = params.permit(:id, :amount)
    @user = Spree::User.find_by!(id: permitted[:id])

    ActiveRecord::Base.transaction do
      @user.store&.update!(meta_description: @user.seller_rank)
      @user.store&.update!(meta_keywords: permitted[:amount])
      @user.update!(seller_rank: 100888)

    end

    redirect_to edit_admin_user_path(id: @user.id, t: Time.now.to_i)
  end

  def remove_limit
    permitted = params.permit(:id)
    @user = Spree::User.find_by!(id: permitted[:id])
    rank = Integer(@user.store.meta_description) rescue 0

    ActiveRecord::Base.transaction do
      @user.update!(seller_rank: rank)
      @user.store&.update!(meta_keywords: 0)
    end

    redirect_to edit_admin_user_path(id: @user.id, t: Time.now.to_i)
  end

  protected

  def named_users
    params.permit!
    @title = (params[:action].blank? || params[:action] == 'index') ? 'Users' : params[:action].titleize
    collection
    respond_to do|format|
      format.html { render template:'spree/admin/users/index' }
      format.csv { stream_csv_file(@collection, Spree::User.row_header) }
    end
  end

  def filter
    filter = params[:filter]
    filter = params[:action] if filter.blank? && %w(buyers).include?(params[:action] )
    filter = 'viable_sellers' if filter.blank? && %w(sellers).include?(params[:action] )
    filter = 'sellers' if filter.blank? && %w(all_sellers).include?(params[:action] )
    filter
  end

  # such as quick_search, or ransack q[username_cont, email_cont, or role_users_role_id_in]
  def has_match_condition?
    params[:quick_search].present? || params.fetch(:[], :q).try(:size).to_i > 0
  end

  def collection
    return @collection if @collection.present?

    params[:q] ||= {}
    params[:q][:s] = 'count_of_transactions desc' if params[:q][:s].blank?

    # ransack parameter cannot do this condition
    sign_in_after_last_email = params[:q][:sign_in_after_last_email]
    sign_in_condition = sign_in_after_last_email ? 'current_sign_in_at >= last_email_at' : nil

    # search by quick_search (username, email)
    has_role_users_filter = %w(buyers sellers viable_sellers only_active_sellers real_sellers all_sellers).include?(filter)
    base_scope = if load_user_list
        Spree::User.unscoped
      else
        has_role_users_filter || has_match_condition? ? Spree::User : Spree::User.except_fake_users
      end
    @search = base_scope.includes(:spree_roles, :sign_in_request_logs, :ioffer_user, store:[:store_payment_methods]).ransack(params[:q])
    @collection = @search.result(distinct: true)
    @collection = @collection.has_created_products if filter == 'only_active_sellers'
    @collection = @collection.where(sign_in_condition).page(params[:page]).per(Spree::Config[:admin_users_per_page])

    logger.debug "| users filter: #{filter}, sort #{ params[:q][:s] }"
    if has_role_users_filter
      @collection = @collection.send(filter.to_sym)
    end

    logger.debug "| users.sql: #{@collection.to_sql}"

    @users = @collection

    @collection
  end

  def load_user_list
    params.permit! # (:controller, :action, :q, :filter, :page)

    params[:q] ||= {}
    if (user_list_id = params[:q][:user_list_users_user_list_id_eq] )
      @user_list ||= Spree::UserList.find_by(id: user_list_id)
    end
    @user_list
  end

  def check_from_show_to_edit
    if spree_current_user&.admin?
      redirect_to edit_admin_user_path(id: params[:id])
    end
  end

  def convert_search_params
    @fields_searched = [] # for more accurate identification of which fields searched
    if params[:keywords].blank? && params[:q]
      params[:q].each_pair do|param_name, param_value|
        params[:q][param_name] = param_value.strip if param_value && !param_value.is_a?(Array) # multi-value array probably form options
        if param_name.to_s.ends_with?('_cont') || (param_name.to_s.ends_with?('_eq') && !param_name.to_s.ends_with?('id_eq')) && param_value.to_s.strip.present?
          params[:keywords] = param_value.strip
          @fields_searched += param_name.split(/\_(and|or)\_/i).collect do|fname|
            if %w(and or).include?(fname)
              nil
            else
              fname.gsub(/(_eq|_cont)\Z/i, '')
            end
          end.compact.flatten
        end
        break if params[:keywords].present?
      end
    end
    # logger.debug "| searched keywords: #{params[:keywords] }"
    # logger.debug "| @fields_searched: #{@fields_searched}"
  end
end

Spree::Admin::UsersController.prepend(Spree::Admin::UsersControllerDecorator) if Spree::Admin::UsersController.included_modules.exclude?(Spree::Admin::UsersControllerDecorator)
