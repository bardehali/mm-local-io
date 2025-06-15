class Ioffer::BrandsController < Ioffer::IofferBaseController

  before_action :check_signed_in_user

  def index
    @page_title = spree_current_user&.full_seller? ? t('store.what_brands_do_you_have') : t('store.what_categories_do_you_supply')

    @categories_map = Ioffer::Category.all.group_by(&:name)
    render 'home/brands'
  end

  def select_brands
    params.permit(:authenticity_token, :category_ids, :brand_ids, :taxon_ids, :option_value_ids, :commit)
    if current_user
      brand_ids = Ioffer::Brand.where(id: params[:brand_ids] || [] ).collect(&:id)
      if brand_ids.size > 0
        Ioffer::UserBrand.where(user_id: current_user.id).delete_all
        brand_ids.each{|brand_id| Ioffer::UserBrand.create(user_id: current_user.id, brand_id: brand_id) }
      end

      category_ids = Ioffer::Category.where(id: params[:category_ids] || [] ).collect(&:id)
      if category_ids.size > 0
        Ioffer::UserCategory.where(user_id: current_user.id).delete_all
        category_ids.each{|category_id| Ioffer::UserCategory.create(user_id: current_user.id, category_id: category_id) }
      end

      current_user.convert_categories!
    end

    if spree_current_user
      taxons_ids = Spree::Taxon.where(id: params[:taxon_ids] || [] ).collect(&:id)
      if taxons_ids.size > 0
        Spree::UserSellingTaxon.where(user_id: spree_current_user.id).delete_all
        taxons_ids.each{|taxon_id| Spree::UserSellingTaxon.create(user_id: spree_current_user.id, taxon_id: taxon_id) }
      end

      option_value_ids = Spree::OptionValue.where(id: params[:option_value_ids] || [] ).collect(&:id)
      if option_value_ids.size > 0
        Spree::UserSellingOptionValue.where(user_id: spree_current_user.id).delete_all
        option_value_ids.each{|ov_id| Spree::UserSellingOptionValue.create(user_id: spree_current_user.id, option_value_id: ov_id) }
      end
    end

    session[:reset_password_source] = nil

    respond_to do|format|
      format.js { render(js:'') }
      format.html { redirect_to (spree_current_user&.full_seller? ? 
        admin_wanted_products_path : "/admin/products?t=#{Time.now.to_i}") }
    end
  end
end
