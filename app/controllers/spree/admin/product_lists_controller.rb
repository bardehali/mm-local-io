class Spree::Admin::ProductListsController < Spree::Admin::ResourceController
  def index
    
  end

  def show
    respond_to do|format|
      format.html { redirect_to edit_admin_product_list_path(@product_list) }
      format.csv {
        
        send_data ::Spree::Service::ProductExporter.new(@product_list.products).to_csv, filename:"#{@product_list.name}-#{Time.now.strftime('%Y-%m-%d-%H-%M')}.csv" 
      }
    end
  end

  def edit
    @product_list
  end

  def remove_product
    params.permit(:id, :product_list_id, :product_list, :product_id, :selector)
    @product_list = Spree::ProductList.find_by(id: params[:id])
    if @product_list && params[:product_id] 
      @product_list.product_list_products.where(product_id: params[:product_id] ).delete_all
    end

    respond_to do|format|
      format.js
    end
  end

  protected

  ##
  # Override to include associations used in admin.
  def find_resource
    if parent_data.present?
      parent.send(controller_name).find(params[:id])
    else
      model_class.includes(products:[:user, :slave_products]).find(params[:id])
    end
  end

end