module Spree::User::Actions

  ##
  # Saving after calculate
  def schedule_to_calculate_stats!
    return if self.skip_calculate_stats
    if respond_to?(:calculate_stats_without_delay!)
      if Delayed::Job.for_record(self).all.to_a.find{|dj| dj.performable_method_name == 'calculate_stats!' }.nil?
        self.calculate_stats!
      end
    else
      self.calculate_stats!
    end
  end

  def calculate_stats!
    return if self.skip_calculate_stats
    h = { }
    h[:seller_rank] = calculate_seller_rank if seller_rank.to_i > -1 && seller_rank.to_i < 5500666 && seller_rank.to_i != 100888 #This is to stop HP seller from changing their rank errantly
    h[:count_of_products_created] = self.products.count
    h[:count_of_products_adopted] = self.adopted_products_count
    h[:count_of_transactions] = Spree::Order.complete.not_by_unreal_users.where(seller_user_id: id).count

    self.update_columns(h)

    h
  end

  handle_asynchronously :calculate_stats!, queue:'SELLER_STATS', priority: 7, run_at: Proc.new { 1.hour.from_now } if Rails.env.production?

  NOTIFY_EMAIL_DJ_QUEUE = 'follow_up_emails' unless defined?(NOTIFY_EMAIL_DJ_QUEUE)
  NOTIFY_EMAIL_DELAY_LENGTH = 2.days unless defined?(NOTIFY_EMAIL_DELAY_LENGTH)

  ##
  #
  def notify_about_pending_orders
    q = Spree::Order.complete_but_not_finished.where(seller_user_id: id)
    if q.count > 0
      begin
        SellerMailer.with(user: self).pending_orders.deliver if seller? && !Rails.env.production?
      rescue Exception => delivery_e
        logger.warn "** #{delivery_e.message}}"
        ::UserReport::EmailDelivery.report_delivery_error(self, delivery_e, id) if Rails.env.staging? || Rails.env.production?
      end
      # for now only production has delayed re-check run
      if (dj = Delayed::Job.for_record(self).where(queue: NOTIFY_EMAIL_DJ_QUEUE).last ).nil? && Rails.env.production?
        self.delay(queue: NOTIFY_EMAIL_DJ_QUEUE, run_at: NOTIFY_EMAIL_DELAY_LENGTH.after).notify_about_pending_orders
      end
    end
  end

  ##
  # Override: differentiate b/w buyer and seller (soft delete).
  def destroy
    if self&.seller?
      soft_delete!
    else
      super
    end
  end

  ##
  # @user_report_attributes would be set to User::Report
  def soft_delete!(user_report_attributes = {})
    already_quarantined = self.quarantined?
    self.role_users.find_or_create_by(role_id: Spree::Role.fetch_cached_role('quarantined_user').id )

    delete_time = Time.now
    Spree::Product.where(user_id: id).update_all(iqs: 0)
    Spree::Product.where(user_id: id).each{|p| p.es.delete_document if p.es.exists_in_es? }

    # Spree::Variant.where(user_id: id).update_all(deleted_at: delete_time)
    # var_ids = Spree::Variant.where(user_id: id).select('id, user_id').collect(&:id)
    # Spree::Variant.where(id: var_ids).update_all(discontinue_on: delete_time)
    # Spree::VariantAdoption.where(user_id: id, variant_id: var_ids).update_all(deleted_at: delete_time)

    Spree::LineItem.joins(:order).where("user_id=#{id} and completed_at is null").delete_all
    Spree::LineItem.joins(:order).where("seller_user_id=#{id} and completed_at is null").delete_all

    # this would not trigger before_destroy or after_destroy
    self.update_columns(seller_rank: -1)

    self.delay(queue: 'items').reset_adopted_products!

    UserReport::Quarantine.save_user_report(self, user_report_attributes) unless already_quarantined
  end

  def restore_status!
    bad_role_ids = Spree::Role.bad_roles.collect(&:id)
    self.role_users.where(role_id: bad_role_ids).delete_all

    Spree::Product.where(user_id: id).each do|p|
      p.update_columns(iqs: p.overriding_iqs || Spree::Product::DEFAULT_IQS)
      p.reload
      p.es.reindex_document
    end

    self.update(seller_rank: calculate_seller_rank(true) )

    self.delay(queue: 'items').reset_adopted_products!
  end

  def reset_adopted_products!
    product_ids = Spree::VariantAdoption.joins(:variant).where(user_id: id).select("distinct(product_id)").collect(&:product_id).uniq
    Spree::Product.where(id: product_ids).includes(:variants_including_master_without_order).all.each do|p|
      if p.respond_to?(:schedule_to_update_variants_without_delay! )
        p.schedule_to_update_variants_without_delay!
      else
        p.schedule_to_update_variants!
      end
    end
  end

  MERGE_ACCOUNT_MIGRATE_ADOPTIONS_OR_KEEP_ONLY_LATEST_TRANSACTED = 'migrate' # or 'keep_only_latest_transacted'

  ##
  # From Neil (modified number 5, and 7):
  # 1. Accounts will be consolidated based on the given PayPal email.
  # 2. We will hand pick which account their data is consolidated into.
  # 3. Payment methods and payment instructions are kept the same for that account.
  # 4. All posted items from their accounts will be consolidated into that one account.
  # 5. Migrate all adoptions to one account
  # 6. Sales will be left on old accounts and not migrated to singular final account.
  # 7. Accounts that are being merged in need to be quarantined.s
  # @log_users_into_user_list [Spree::UserList] if given, would save users changed to list.
  #   First being base one.  Neglegible if includes self user.
  # @return [Array of Integer] user IDs of other users.
  def merge_accounts_into_this!(other_users = nil, log_users_into_user_list = nil, user_report_attributes = {})
    if other_users.nil?
      payment_method_id = Spree::PaymentMethod.paypal.id
      store_payment_method = fetch_store.store_payment_methods.to_a.find{|spm| spm.payment_method_id == payment_method_id }
      other_users ||= store_payment_method.same_store_payment_methods.collect{|spm| spm.store.user }.compact if store_payment_method
    end
    return if other_users.blank?

    user = self
    user_ids = other_users.collect(&:id)
    user_ids.delete(id)
    # s = ''
    # Self products created
    Spree::Product.where(user_id: user_ids ).includes(:user).each do|p|
      # s << "Will migrate Product (#{p.id}) created by #{p.user.to_s}\n" if p.user_id != user.id
      p.variants.where("#{Spree::Variant.table_name}.user_id != ?", self.id).update_all(user_id: user.id)
      p.update_columns(user_id: user.id) if p.user_id != id
      p.reload
      p.es.update_document
    end.class

    # Adoptions
    if MERGE_ACCOUNT_MIGRATE_ADOPTIONS_OR_KEEP_ONLY_LATEST_TRANSACTED == 'keep_only_latest_transacted'
      Spree::Variant.distinct.joins(:variant_adoptions).with_deleted.
        where("#{Spree::VariantAdoption.table_name}.user_id IN (?)", user_ids ).in_batches do|subq|
        subq.includes(:option_values).each do|v|
          last_trx_li = Spree::LineItem.joins(:order).where("completed_at IS NOT NULL and state='complete'").where(variant_id: v.id).where("seller_user_id IN (?)", user_ids).includes(:order).order('completed_at DESC').first
          # s << "  Variant (#{v.id}) #{v.sku_and_options_text} ----------------\n"
          va_to_keep =
            if last_trx_li && last_trx_li.variant_adoption_id
              # s << "Last order: #{last_trx_li.order.number} $#{last_trx_li.price} at #{last_trx_li.order.completed_at}"
              last_trx_li.variant_adoption
            else
              v.variant_adoptions.joins(:default_price).where(user_id: user_ids).includes(:user, :default_price).order("amount desc").first
            end
          v.variant_adoptions.where(user_id: user_ids).includes(:user, :default_price).each do|va|
            next if va_to_keep.id == va.id
            # s << "  Will end variant adoption of #{va.user.to_s} $#{va.price.to_f}\n"
            va.update_columns(deleted_at: Time.now)
          end if va_to_keep
        end
      end.class

    else
      adoption_q = Spree::VariantAdoption.with_deleted.where(user_id: user_ids)
      # s << "Will migrate %d adoptions to #{user.to_s}" % [adoption_q.count]
      adoption_q.update_all(user_id: user.id)

      Spree::Variant.with_deleted.adopted.where(user_id: user_ids).update_all(user_id: user.id)
    end

    Spree::User.where(id: user_ids).where("id != ?", user.id).all.each do|u|
      u.soft_delete!
    end

    UserReport::MergeAccounts.save_user_report(self, user_report_attributes) unless already_quarantined

    user_ids
  end

  alias_method :steiner_recline!, :merge_accounts_into_this!


end
