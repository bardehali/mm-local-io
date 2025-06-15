class Spree::Admin::UserListsController < Spree::Admin::ResourceController
  def index
    
  end

  def show
    load_resource
    respond_to do|format|
      format.json { render json: @object.users.collect(&:as_json) }
    end
  end

  def remove_user
    params.permit(:id, :user_list_id, :user_list, :user_id, :selector)
    @user_list = Spree::UserList.find_by(id: params[:id])
    if @user_list && params[:user_id] 
      @user_list.user_list_users.where(user_id: params[:user_id] ).delete_all
    end

    respond_to do|format|
      format.js
    end
  end
end