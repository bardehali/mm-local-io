class Ioffer::CategoriesController < Ioffer::IofferBaseController

  before_action :check_signed_in_user

  def index
    PageLog.record_request(request)
    render 'home/index'
  end

  def select_categories
    params.permit(:category_ids)
    category_ids = Ioffer::Category.where(id: params[:category_ids] || [] ).collect(&:id)
    if current_user
      if category_ids.size > 0
        Ioffer::UserCategory.where(user_id: current_user.id).delete_all
        category_ids.each{|category_id| Ioffer::UserCategory.create(user_id: current_user.id, category_id: category_id) }
      end

      spree_user = current_user.convert_to_spree_user!
      current_user.convert_categories!(spree_user)
    end

    respond_to do|format|
      format.js { render(js:'') }
      format.html { redirect_to ioffer_brands_path(t: Time.now.to_i) }
    end
  end
end
