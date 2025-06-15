class SellerMailer < ApplicationMailer

  def pending_orders
    @user = params[:user]
    q = Spree::Order.complete_but_not_finished.where(seller_user_id: @user.id)
    @orders_count = q.count
    @order = q.last
    
    @url = URI.join( host, ::Spree::Core::Engine.routes.url_helpers.admin_sales_in_state_path(state: 'complete') )
    
    mail(to: @user.email, subject:"#{@user.try_display_name}, you have a new message")
  end

end
