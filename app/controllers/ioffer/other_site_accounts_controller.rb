class Ioffer::OtherSiteAccountsController < Ioffer::IofferBaseController

  before_action :check_signed_in_user

  def create
    params.permit!
    params.each_pair do|site_account, account_id|
      site_name = "#{site_account}"
      site_name.gsub!(/(_account_id)\Z/, '')
      if %(aliexpress dhgate).include?(site_name.downcase) && account_id.present?
        logger.info "| site #{site_name} = #{account_id}"
        other_site_account = Retail::OtherSiteAccount.find_or_initialize_by(user_id: spree_current_user.id, site_name: site_name )
        other_site_account.account_id = account_id
        other_site_account.save
        logger.debug "| other #{site_name} valid? #{other_site_account.valid?}, w/ #{other_site_account.errors.messages}"
      end
    end

    current_user.convert_other_site_accounts!

    redirect_to ioffer_brands_path(t: Time.now.to_i)
  end

end
